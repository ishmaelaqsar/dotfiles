;;; kdb.el --- Query a remote kdb server from a local q shell  -*- lexical-binding: t; -*-

;;; Commentary:

;; A kdb query workbench on q-mode.
;;
;; A q buffer is bound to one target from `kdb-targets'.  The first run asks
;; for the target and keeps it.  `C-c C-c' sends the statement at point; the
;; run hint above each statement does the same on a click.  The q-mode eval
;; keys send the text as written.  `C-c k n' opens a scratch q buffer bound
;; to a target, and `C-c k s' saves the region as a dated query file.
;;
;; Each target has a `kdb-shell-mode' buffer: a local q process, started
;; with kdb-driver.q, that holds one handle to the remote server.  Text sent
;; to it runs remotely and prints at a wide console.  Two prefixes stay
;; local: `\' for a q system command, and `kdb-local-prefix' (`%'), which
;; is stripped.  `.kdb.last' in the local q holds the last remote result.
;;
;; A table result opens in a `kdb-grid-mode' buffer: a `tabulated-list' with
;; a frozen header and sortable columns; `f' filters the rows.  The window
;; opens under the frame; `kdb-grid-window' moves it, and `C-c k q' closes it
;; from any window.
;;
;; Completion at point offers the target's table names anywhere, and the
;; columns of each table named in the statement at point, together with
;; q-mode's keywords.  `C-c k T' shows `meta' of a table.  The schema loads
;; when a buffer is bound to a target; `C-c k R' loads it again.
;;
;; `kdb-targets' is empty here.  A site file, kdb-site.el, sets it, with
;; `kdb-qhome' when the machine needs it.  `kdb-query-directory' comes from
;; the KDB_QUERY_DIR environment variable.  With no targets, the eval keys
;; call q-mode's own commands.

;;; Code:

(require 'comint)
(require 'q-mode)
(require 'tabulated-list)

(defgroup kdb nil "Remote kdb servers through a local q shell." :group 'q)

(defcustom kdb-targets nil
  "Alist of remote kdb servers.
Each element is (NAME . PLIST).  PLIST has :host, :port, and :user; :user
may be nil for an empty login.  A non-nil :production only changes the
header line of the shell buffer."
  :type '(alist :key-type (string :tag "name")
                :value-type (plist :options (:host :port :user :production)))
  :group 'kdb)

(defcustom kdb-local-prefix "%"
  "Prefix that routes a send to the local q instead of the remote server.
The prefix is stripped before the text is sent."
  :type 'string
  :group 'kdb)

(defcustom kdb-query-directory (getenv "KDB_QUERY_DIR")
  "Directory where `kdb-save-query' writes files.
The default is the KDB_QUERY_DIR environment variable.  Nil prompts for
the directory on every save."
  :type '(choice (const nil) directory)
  :group 'kdb)

(defcustom kdb-qhome nil
  "Value for the QHOME environment variable of the local q, or nil.
q reads its licence from QHOME.  Set this when the shell does not export it."
  :type '(choice (const nil) directory)
  :group 'kdb)

(defcustom kdb-grid-auto t
  "When non-nil, every table result opens in a `kdb-grid-mode' buffer.
`kdb-grid' opens one on demand either way."
  :type 'boolean
  :group 'kdb)

(defcustom kdb-grid-max-rows 5000
  "Most rows the grid loads from one result.
The mode line shows how many rows the result had."
  :type 'natnum
  :group 'kdb)

(defcustom kdb-grid-window 'bottom
  "Where the grid buffer opens.
`bottom' is a full-width window under the frame, `right' a window beside
the selected one, and nil leaves the choice to `display-buffer-alist'."
  :type '(choice (const bottom) (const right) (const nil))
  :group 'kdb)

(defcustom kdb-grid-window-size 0.4
  "Fraction of the frame the grid window takes.
Its height when at the bottom, its width when at the right."
  :type 'number
  :group 'kdb)

(defcustom kdb-hints t
  "When non-nil, `kdb-mode' shows a run hint above every statement."
  :type 'boolean
  :group 'kdb)

(defface kdb-hint-face
  '((t :inherit shadow))
  "Face of the run hint above a statement."
  :group 'kdb)

(defconst kdb-driver-file
  (expand-file-name "kdb-driver.q"
                    (file-name-directory (or load-file-name buffer-file-name)))
  "The q file the local process loads at start.")

(defvar-local kdb--target nil
  "In a shell buffer, the (NAME . PLIST) entry of `kdb-targets' it talks to.")

(defvar-local kdb--banner-pending t
  "In a shell buffer, non-nil until the q banner has been removed.")

(defvar-local kdb-buffer-target nil
  "In a `.q' buffer, the name of the `kdb-targets' entry it runs against.")
(put 'kdb-buffer-target 'safe-local-variable #'stringp)

(defvar kdb--schemas (make-hash-table :test #'equal)
  "Schema of each target: its name to an alist of (TABLE . COLUMNS), all strings.")

(declare-function cape-capf-super "cape")

;;;; Shell buffer

(defun kdb--q-string (text)
  "Return TEXT as a q string literal."
  (concat "\""
          (replace-regexp-in-string
           "\n" "\\\\n"
           (replace-regexp-in-string "[\"\\\\]" "\\\\\\&" text))
          "\""))

(defun kdb--input-sender (proc string)
  "Send STRING to PROC, the local q, for local or remote evaluation.
`q-eval-region' prepends `q-eval-prefix' for a local q shell; that
prefix is removed first, because the remote server does the display."
  (let ((text (string-remove-prefix q-eval-prefix string)))
    (comint-simple-send
     proc
     (cond ((string-prefix-p "\\" text) text)
           ((and (not (string-empty-p kdb-local-prefix))
                 (string-prefix-p kdb-local-prefix text))
            (string-remove-prefix kdb-local-prefix text))
           (t (concat ".kdb.run " (kdb--q-string text)))))))

(defun kdb--header-line ()
  "Return the header line for the shell buffer of `kdb--target'."
  (let* ((name (car kdb--target))
         (plist (cdr kdb--target)))
    (list " " name "  "
          (format "%s:%s" (plist-get plist :host) (plist-get plist :port))
          (when (plist-get plist :production)
            (propertize "  PROD" 'face 'warning))
          ;; A % in a mode-line string starts a %-construct.
          (format "    %s local   \\ system   .kdb.last"
                  (replace-regexp-in-string "%" "%%" kdb-local-prefix t t)))))

(defun kdb--process-sentinel (process message)
  "Record that PROCESS ended with MESSAGE, and save the input history."
  (comint-write-input-ring)
  (let ((buffer (process-buffer process)))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (goto-char (point-max))
        (insert-before-markers
         (format "\nProcess %s %s at %s\n" (process-name process)
                 (string-trim-right message) (current-time-string)))))))

(defun kdb--output-filter (_output)
  "Act on the marker lines of the shell process, after each output chunk.
A `kdb-grid:' line names a CSV file of a table result: load it into the
grid.  A `kdb-schema:' line names the schema file: load it into
`kdb--schemas'.  Both lines are removed.  The first `kdb: connected' line
ends the q banner: remove everything before it."
  (let ((proc (get-buffer-process (current-buffer)))
        (start (or (and comint-last-output-start
                        (marker-position comint-last-output-start))
                   (point-min))))
    (when proc
      (save-excursion
        (goto-char start)
        (forward-line 0)
        (while (re-search-forward "^kdb-grid: \\(.+\\) rows=\\([0-9]+\\)$"
                                  (process-mark proc) t)
          (let ((path (match-string 1))
                (total (string-to-number (match-string 2))))
            (delete-region (match-beginning 0)
                           (min (1+ (match-end 0)) (point-max)))
            (condition-case err
                (kdb--grid-load path total (car kdb--target))
              (error (message "kdb grid: %s" (error-message-string err))))))
        (goto-char start)
        (forward-line 0)
        (while (re-search-forward "^kdb-schema: \\(.+\\)$" (process-mark proc) t)
          (let ((path (match-string 1)))
            (delete-region (match-beginning 0)
                           (min (1+ (match-end 0)) (point-max)))
            (condition-case err
                (kdb--schema-load path (car kdb--target))
              (error (message "kdb schema: %s" (error-message-string err))))))
        (when kdb--banner-pending
          (goto-char start)
          (forward-line 0)
          (when (re-search-forward "^kdb: connected" (process-mark proc) t)
            (delete-region (point-min) (line-beginning-position))
            (setq kdb--banner-pending nil)))))))

(define-derived-mode kdb-shell-mode q-shell-mode "KDB"
  "Major mode for a local q shell that relays to a remote kdb server.
Derived from `q-shell-mode', so q-mode treats the buffer as a q shell."
  (setq-local comint-input-sender #'kdb--input-sender)
  (setq-local truncate-lines t)
  (font-lock-add-keywords nil '(("^ERR: .*" 0 'error t)
                                ("^kdb: connected.*" 0 'success t)))
  (add-hook 'comint-output-filter-functions #'kdb--output-filter nil t))

(defun kdb--target-environment (name plist)
  "Return the process environment for a shell on target NAME with PLIST."
  (append (list "KX_LINE=0"
                (concat "KDB_NAME=" name)
                (concat "KDB_HOST=" (plist-get plist :host))
                (format "KDB_PORT=%s" (plist-get plist :port))
                (concat "KDB_USER=" (or (plist-get plist :user) ""))
                (concat "KDB_GRID=" (if kdb-grid-auto "1" "0"))
                (concat "KDB_GRID_DIR="
                        (directory-file-name (expand-file-name temporary-file-directory)))
                (format "KDB_GRID_ROWS=%d" kdb-grid-max-rows))
          (when kdb-qhome
            (list (concat "QHOME=" (expand-file-name kdb-qhome))))
          process-environment))

(defun kdb--ensure-shell (name)
  "Return the shell buffer of the `kdb-targets' entry NAME, started if needed."
  (let* ((target (assoc name kdb-targets))
         (buffer (get-buffer-create (format "*kdb: %s*" name))))
    (unless target
      (user-error "No target named %s in `kdb-targets'" name))
    (unless (comint-check-proc buffer)
      (with-current-buffer buffer
        (kdb-shell-mode)
        (setq kdb--target target
              kdb--banner-pending t
              header-line-format (kdb--header-line)
              comint-input-ring-file-name (expand-file-name "~/.q_history"))
        (comint-read-input-ring t)
        (let ((process-environment (kdb--target-environment name (cdr target))))
          (comint-exec buffer "kdb" q-program nil (list kdb-driver-file)))
        (set-process-sentinel (get-buffer-process buffer) #'kdb--process-sentinel)))
    buffer))

(defun kdb--read-target ()
  "Ask for a target name from `kdb-targets'."
  (unless kdb-targets
    (user-error "`kdb-targets' is empty; a site file has to set it"))
  (completing-read "KDB target: " (mapcar #'car kdb-targets) nil t))

;;;###autoload
(defun kdb-connect (name)
  "Open, or switch to, the shell on the `kdb-targets' entry NAME.
The shell becomes the active q buffer.  In a q buffer, NAME also
becomes the buffer's target."
  (interactive (list (kdb--read-target)))
  (let ((buffer (kdb--ensure-shell name)))
    (when (derived-mode-p 'q-mode)
      (kdb-set-target name))
    (q-activate-buffer buffer)
    (pop-to-buffer buffer)))

;;;; Buffer target and sending

;;;###autoload
(defun kdb-scratch (name)
  "Open a q buffer for ad-hoc queries against the `kdb-targets' entry NAME.
The buffer is `*kdb scratch: NAME*', in `q-mode' with `kdb-mode' on."
  (interactive (list (kdb--read-target)))
  (let ((buffer (get-buffer-create (format "*kdb scratch: %s*" name))))
    (with-current-buffer buffer
      (unless (derived-mode-p 'q-mode)
        (q-mode))
      (kdb-mode 1)
      (kdb-set-target name))
    (pop-to-buffer buffer)))

(defun kdb--header-target ()
  "Return the target named on the buffer's `/ env/db :' header line, or nil."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward "^/ env/db[ \t]*:[ \t]*\\([^ \t\n]+\\)"
                             (min (point-max) 2000) t)
      (let ((name (match-string-no-properties 1)))
        (and (assoc name kdb-targets) name)))))

(defun kdb-set-target (name)
  "Bind the current buffer to the `kdb-targets' entry NAME.
The target's shell starts, so its schema is loaded for completion."
  (interactive (list (kdb--read-target)))
  (setq kdb-buffer-target name)
  (kdb--ensure-shell name)
  (kdb--hints-refresh)
  name)

(defun kdb--buffer-target ()
  "Return the buffer's target, from the header line or a prompt when unset."
  (or kdb-buffer-target
      (kdb-set-target (or (kdb--header-target) (kdb--read-target)))))

(defun kdb--shell ()
  "Return the shell buffer for the current buffer, started if needed."
  (if kdb--target
      (current-buffer)
    (kdb--ensure-shell (kdb--buffer-target))))

(defun kdb--send (text &optional span)
  "Send TEXT to the current buffer's shell, with source SPAN for q-mode."
  (q-activate-buffer (kdb--shell))
  (q-send-string text span))

(defun kdb-reconnect ()
  "Open the remote handle of the current buffer's shell again."
  (interactive)
  (kdb--send (concat kdb-local-prefix ".kdb.connect[]")))

(defun kdb-grid ()
  "Open the last remote result of the current buffer's shell in a grid."
  (interactive)
  (kdb--send (concat kdb-local-prefix ".kdb.grid .kdb.last")))

(defun kdb-grid-quit ()
  "Close the grid window of the current buffer's target, from any window."
  (interactive)
  (let* ((name (or kdb-buffer-target (car kdb--target)))
         (buffer (and name (get-buffer (format "*kdb grid: %s*" name))))
         (window (and buffer (get-buffer-window buffer))))
    (if window
        (quit-window nil window)
      (message "No grid window for %s" (or name "this buffer")))))

;;;; Eval commands

;; `q-eval-region' strips comments and blank lines and folds indented lines
;; before it sends, which suits a local q but merges the statements of a
;; query file.  These send the text as written.

(defun kdb--span (start end)
  "Return the (BEG . END) line span around START..END for q-mode."
  (cons (save-excursion (goto-char start) (line-beginning-position))
        (save-excursion (goto-char end) (line-end-position))))

(defun kdb-eval-region (start end)
  "Send the text between START and END, as written, to the buffer's shell.
With no `kdb-targets', call `q-eval-region' instead."
  (interactive "r")
  (if (null kdb-targets)
      (q-eval-region start end)
    (kdb--send (buffer-substring-no-properties start end) (kdb--span start end))
    (setq deactivate-mark t)))

(defun kdb-eval-line ()
  "Send the current line, as written, to the buffer's shell."
  (interactive)
  (kdb-eval-region (line-beginning-position) (line-end-position)))

(defun kdb-eval-buffer ()
  "Send the whole buffer, as written, to the buffer's shell."
  (interactive)
  (kdb-eval-region (point-min) (point-max)))

(defun kdb--separator-line-p ()
  "Return non-nil when the current line is blank or a `/' comment."
  (save-excursion
    (forward-line 0)
    (looking-at-p "[ \t]*\\(/\\|$\\)")))

(defun kdb--statement-bounds ()
  "Return (BEG . END) of the statement at point.
A statement is a run of lines with no blank line and no comment line,
the rule of kdb-driver.q and run.sh."
  (when (kdb--separator-line-p)
    (user-error "Point is not on a statement"))
  (cons (save-excursion
          (while (and (not (kdb--separator-line-p)) (zerop (forward-line -1))))
          (when (kdb--separator-line-p) (forward-line 1))
          (point))
        (save-excursion
          (while (and (not (kdb--separator-line-p)) (zerop (forward-line 1))))
          (if (kdb--separator-line-p) (line-beginning-position) (point-max)))))

(defun kdb-eval-statement (&optional ask)
  "Send the statement at point to the buffer's shell.
With a prefix argument ASK, choose the target first."
  (interactive "P")
  (when ask (call-interactively #'kdb-set-target))
  (let ((bounds (kdb--statement-bounds)))
    (kdb-eval-region (car bounds) (cdr bounds))))

(defun kdb-eval-statement-at-mouse (event)
  "Send the statement under the run hint clicked in EVENT."
  (interactive "e")
  (mouse-set-point event)
  (kdb-eval-statement))

;;;; Run hints

(defvar kdb-mode)

(defvar kdb--hint-keymap (make-sparse-keymap)
  "Keymap of the run hint text.")
(define-key kdb--hint-keymap [mouse-1] #'kdb-eval-statement-at-mouse)

(defvar-local kdb--hint-timer nil
  "Idle timer that refreshes the run hints after an edit.")

(defun kdb--hint-at (pos)
  "Put a run hint above the statement whose first line is at POS."
  (let ((ov (make-overlay pos (min (1+ pos) (point-max)))))
    (overlay-put ov 'kdb-hint t)
    (overlay-put ov 'evaporate t)
    (overlay-put ov 'before-string
                 (propertize (format "▶ run  C-c C-c  ·  %s\n"
                                     (or kdb-buffer-target "choose target on run"))
                             'face 'kdb-hint-face
                             'mouse-face 'highlight
                             'keymap kdb--hint-keymap
                             'help-echo "mouse-1: run this statement"))))

(defun kdb--hints-refresh (&optional buffer)
  "Draw the run hints of BUFFER, the current buffer by default, afresh."
  (with-current-buffer (or buffer (current-buffer))
    (setq kdb--hint-timer nil)
    (remove-overlays (point-min) (point-max) 'kdb-hint t)
    (when (and kdb-mode kdb-hints)
      (save-excursion
        (goto-char (point-min))
        (let ((in-statement nil))
          (while (not (eobp))
            (if (kdb--separator-line-p)
                (setq in-statement nil)
              (unless in-statement
                (setq in-statement t)
                (kdb--hint-at (line-beginning-position))))
            (forward-line 1)))))))

(defun kdb--hints-schedule (&rest _)
  "Refresh the run hints once the buffer has been idle for a moment."
  (when kdb--hint-timer
    (cancel-timer kdb--hint-timer))
  (setq kdb--hint-timer
        (run-with-idle-timer 0.3 nil #'kdb--hints-refresh (current-buffer))))

;;;; Grid

(defvar-local kdb--grid-rows nil
  "Every row of the grid, as `tabulated-list-entries', before any filter.")

(defvar-local kdb--grid-filter nil
  "The regexp that rows must match, or nil for every row.")

(defvar-local kdb--grid-total 0
  "How many rows the result had, loaded or not.")

(defun kdb--csv-fields (line)
  "Split LINE, one CSV record as q writes it, into a list of fields."
  (let ((fields nil) (pos 0) (len (length line)))
    (while (<= pos len)
      (if (and (< pos len) (eq (aref line pos) ?\"))
          (let ((parts nil) (done nil))
            (setq pos (1+ pos))
            (while (not done)
              (let ((quote (string-search "\"" line pos)))
                (unless quote
                  (error "Unterminated quote in CSV"))
                (push (substring line pos quote) parts)
                (if (and (< (1+ quote) len) (eq (aref line (1+ quote)) ?\"))
                    (progn (push "\"" parts) (setq pos (+ quote 2)))
                  (setq pos (1+ quote) done t))))
            (push (apply #'concat (nreverse parts)) fields)
            (setq pos (1+ pos)))
        (let ((comma (or (string-search "," line pos) len)))
          (push (substring line pos comma) fields)
          (setq pos (1+ comma)))))
    (nreverse fields)))

(defconst kdb--number-regexp
  "\\`-?\\(?:[0-9]*\\.?[0-9]+\\(?:e[-+]?[0-9]+\\)?\\|0[nNwW]\\)\\'"
  "A q number as csv 0: prints it, including the null and infinities.")

(defun kdb--numeric-column-p (rows index)
  "Return non-nil when every cell of column INDEX of ROWS is a number or blank."
  (let ((numeric t))
    (dolist (row rows numeric)
      (let ((cell (aref (cadr row) index)))
        (unless (or (string-empty-p cell) (string-match-p kdb--number-regexp cell))
          (setq numeric nil))))))

(defun kdb--numeric-sorter (index)
  "Return a sort predicate for `tabulated-list' on numeric column INDEX."
  (lambda (a b)
    (< (string-to-number (aref (cadr a) index))
       (string-to-number (aref (cadr b) index)))))

(defun kdb--grid-format (names rows)
  "Return the `tabulated-list-format' for columns NAMES over ROWS."
  (let ((index -1))
    (apply #'vector
           (mapcar
            (lambda (name)
              (setq index (1+ index))
              (let* ((i index)
                     (width (min 60 (max 3 (length name)
                                         (apply #'max 0 (mapcar (lambda (r) (length (aref (cadr r) i)))
                                                                rows)))))
                     (numeric (kdb--numeric-column-p rows i)))
                (list name width (if numeric (kdb--numeric-sorter i) t)
                      :right-align numeric)))
            names))))

(defvar kdb-grid-mode-map (make-sparse-keymap)
  "Keymap for `kdb-grid-mode'.")
(define-key kdb-grid-mode-map "f" #'kdb-grid-filter)

(define-derived-mode kdb-grid-mode tabulated-list-mode "KDB-Grid"
  "Major mode for a table result: a sortable grid with a frozen header.
Click a column header, or press \\[tabulated-list-sort], to sort by it.
\\{kdb-grid-mode-map}"
  (setq tabulated-list-padding 1))

(defun kdb--grid-print ()
  "Show the rows that match `kdb--grid-filter', and update the mode line."
  (setq tabulated-list-entries
        (if kdb--grid-filter
            (seq-filter (lambda (row)
                          (seq-some (lambda (cell) (string-match-p kdb--grid-filter cell))
                                    (cadr row)))
                        kdb--grid-rows)
          kdb--grid-rows))
  (setq mode-line-process
        (format ": %d/%d rows%s" (length tabulated-list-entries) kdb--grid-total
                (if kdb--grid-filter (format "  /%s/" kdb--grid-filter) "")))
  (tabulated-list-print t))

(defun kdb-grid-filter (regexp)
  "Show only the rows with a cell that matches REGEXP.
An empty REGEXP shows every row."
  (interactive (list (read-regexp "Filter rows (regexp, empty for all)")))
  (setq kdb--grid-filter (and (not (string-empty-p regexp)) regexp))
  (kdb--grid-print))

(defun kdb--grid-load (path total name)
  "Load the CSV file at PATH, TOTAL rows before the cap, into the grid of NAME.
The file is deleted after it is read."
  (let* ((lines (kdb--read-lines path))
         (names (and lines (kdb--csv-fields (car lines))))
         (id 0)
         (rows (mapcar (lambda (line)
                         (let ((cells (kdb--csv-fields line)))
                           (while (< (length cells) (length names))
                             (setq cells (append cells (list ""))))
                           (list (setq id (1+ id)) (apply #'vector cells))))
                       (cdr lines)))
         (buffer (get-buffer-create (format "*kdb grid: %s*" name))))
    (when names
      (with-current-buffer buffer
        (unless (derived-mode-p 'kdb-grid-mode)
          (kdb-grid-mode))
        (setq tabulated-list-format (kdb--grid-format names rows)
              tabulated-list-sort-key nil
              kdb--grid-rows rows
              kdb--grid-filter nil
              kdb--grid-total total)
        (tabulated-list-init-header)
        (kdb--grid-print)
        (goto-char (point-min)))
      (display-buffer buffer (kdb--grid-display-action)))))

(defun kdb--grid-display-action ()
  "Return the `display-buffer' action for `kdb-grid-window'."
  (pcase kdb-grid-window
    ('bottom `((display-buffer-reuse-window display-buffer-at-bottom)
               (window-height . ,kdb-grid-window-size)))
    ('right `((display-buffer-reuse-window display-buffer-in-direction)
              (direction . right)
              (window-width . ,kdb-grid-window-size)))
    (_ nil)))

;;;; Schema and completion

(defun kdb--read-lines (path)
  "Return the lines of the file at PATH, then delete the file."
  (unwind-protect
      (with-temp-buffer
        (insert-file-contents path)
        (split-string (buffer-string) "\n" t))
    (ignore-errors (delete-file path))))

(defun kdb--schema-load (path name)
  "Store the schema file at PATH for target NAME.
The file has one `table col col' line per table."
  (let ((lines (kdb--read-lines path)))
    (puthash name
             (mapcar (lambda (line)
                       (let ((words (split-string line " " t)))
                         (cons (car words) (cdr words))))
                     lines)
             kdb--schemas)
    (message "kdb: %d tables in %s" (length lines) name)))

(defun kdb--schema ()
  "Return the schema alist of the buffer's target, or nil when none is loaded."
  (and kdb-buffer-target (gethash kdb-buffer-target kdb--schemas)))

(defun kdb--statement-tables (schema)
  "Return the entries of SCHEMA whose table is named in the statement at point."
  (condition-case nil
      (let* ((bounds (kdb--statement-bounds))
             (words (split-string (buffer-substring-no-properties (car bounds) (cdr bounds))
                                  "[^A-Za-z0-9_.]+" t)))
        (seq-filter (lambda (entry) (member (car entry) words)) schema))
    (user-error nil)))

(defun kdb-completion-at-point ()
  "Complete the target's table names, and the columns of tables in the statement.
A `completion-at-point-functions' member for buffers with a loaded schema."
  (let ((bounds (bounds-of-thing-at-point 'symbol))
        (schema (kdb--schema)))
    (when (and bounds schema)
      (let ((candidates nil))
        (dolist (entry schema)
          (push (propertize (car entry) 'kdb-kind " table") candidates))
        (dolist (entry (kdb--statement-tables schema))
          (dolist (column (cdr entry))
            (push (propertize column 'kdb-kind (concat " col of " (car entry)))
                  candidates)))
        (list (car bounds) (cdr bounds) candidates
              :annotation-function (lambda (c) (get-text-property 0 'kdb-kind c))
              :exclusive 'no)))))

(defun kdb--capf ()
  "Return the completion function for a `kdb-mode' buffer.
With cape, one function merges the schema source and q-mode's, so tables,
columns, and keywords share one popup."
  (if (fboundp 'cape-capf-super)
      (cape-capf-super #'kdb-completion-at-point #'q-completion-at-point)
    #'kdb-completion-at-point))

(defvar-local kdb--capf-function nil
  "The completion function `kdb-mode' added to this buffer.")

(defun kdb-describe-table (table)
  "Send `meta TABLE' to the buffer's shell.
The result prints there and opens in the grid."
  (interactive
   (list (completing-read "Table: " (mapcar #'car (kdb--schema)) nil nil
                          (thing-at-point 'symbol t))))
  (kdb--send (concat "meta " table)))

(defun kdb-refresh-schema ()
  "Load the schema of the buffer's target again."
  (interactive)
  (kdb--send (concat kdb-local-prefix ".kdb.schema[]")))

;;;; Saving a query

(defun kdb--slug-p (slug)
  "Return non-nil when SLUG is lower-case words joined by hyphens."
  (string-match-p "\\`[a-z0-9]+\\(-[a-z0-9]+\\)*\\'" slug))

(defun kdb-save-query (beg end slug purpose)
  "Save the region BEG..END, or the buffer, as a dated query file.
SLUG names the file, `YYYY-MM-DD-SLUG.q', under `kdb-query-directory'.
PURPOSE fills the first header line.  The env/db line names the buffer's
target, which `kdb--header-target' reads back when the file is opened."
  (interactive
   (let ((slug (read-string "Slug (lower-case-hyphens): ")))
     (unless (kdb--slug-p slug)
       (user-error "Slug must be lower-case words joined by hyphens"))
     (list (if (use-region-p) (region-beginning) (point-min))
           (if (use-region-p) (region-end) (point-max))
           slug
           (read-string "Purpose: "))))
  (let* ((dir (or kdb-query-directory
                  (read-directory-name "Query directory: ")))
         (file (expand-file-name
                (format "%s-%s.q" (format-time-string "%Y-%m-%d") slug) dir))
         (target (or kdb-buffer-target (car kdb--target) ""))
         (text (buffer-substring-no-properties beg end)))
    (when (file-exists-p file)
      (user-error "%s exists" file))
    (make-directory dir t)
    (with-temp-file file
      (insert (format "/ purpose : %s\n" purpose)
              (format "/ env/db  : %s\n" target)
              (format "/ ran     : %s\n" (format-time-string "%Y-%m-%d"))
              "/ result  : \n\n"
              (string-trim-right text) "\n"))
    (find-file file)
    (message "Saved %s" file)))

;;;; Keys and modes

;; The keys sit outside the defvar, so a reload of this file updates them.
(defvar kdb-map (make-sparse-keymap)
  "Prefix keymap for the kdb commands.")
(define-key kdb-map "c" #'kdb-connect)
(define-key kdb-map "n" #'kdb-scratch)
(define-key kdb-map "t" #'kdb-set-target)
(define-key kdb-map "r" #'kdb-reconnect)
(define-key kdb-map "g" #'kdb-grid)
(define-key kdb-map "q" #'kdb-grid-quit)
(define-key kdb-map "T" #'kdb-describe-table)
(define-key kdb-map "R" #'kdb-refresh-schema)
(define-key kdb-map "s" #'kdb-save-query)
(define-key kdb-map "z" #'q-show-q-buffer)
(fset 'kdb-map kdb-map)

(define-key kdb-shell-mode-map (kbd "C-c k") kdb-map)

(defvar kdb-mode-map (make-sparse-keymap)
  "Keymap for `kdb-mode'.")
(define-key kdb-mode-map (kbd "C-c C-c") #'kdb-eval-statement)
(define-key kdb-mode-map [remap q-eval-line] #'kdb-eval-line)
(define-key kdb-mode-map [remap q-eval-region] #'kdb-eval-region)
(define-key kdb-mode-map [remap q-eval-buffer] #'kdb-eval-buffer)
(define-key kdb-mode-map (kbd "C-c k") kdb-map)

;;;###autoload
(define-minor-mode kdb-mode
  "Run the statements of a q buffer against a kdb target.
\\[kdb-eval-statement] sends the statement at point; the q-mode eval keys
send as written.  The first run asks for the target and keeps it; a prefix
argument asks again.  Each statement shows a run hint that a click runs.
Completion offers the target's tables and the columns of tables in the
statement.
\\{kdb-mode-map}"
  :lighter " KDB"
  :keymap kdb-mode-map
  (if kdb-mode
      (progn
        (setq kdb--capf-function (kdb--capf))
        (add-hook 'completion-at-point-functions kdb--capf-function nil t)
        (add-hook 'after-change-functions #'kdb--hints-schedule nil t)
        ;; A saved query file names its target on the header line.
        (let ((name (and (not kdb-buffer-target) (kdb--header-target))))
          (when name (kdb-set-target name)))
        (kdb--hints-refresh))
    (remove-hook 'completion-at-point-functions kdb--capf-function t)
    (remove-hook 'after-change-functions #'kdb--hints-schedule t)
    (remove-overlays (point-min) (point-max) 'kdb-hint t)))

(provide 'kdb)

;;; kdb.el ends here
