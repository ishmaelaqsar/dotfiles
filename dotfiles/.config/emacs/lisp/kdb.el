;;; kdb.el --- Query a remote kdb server from a local q shell  -*- lexical-binding: t; -*-

;;; Commentary:

;; A thin layer on q-mode.  `kdb-connect' starts a local q process that loads
;; kdb-driver.q, which opens one handle to a remote kdb server named in
;; `kdb-targets'.  The buffer is a `q-shell-mode' buffer, so every q-mode
;; eval command (C-c C-l, C-c C-r, C-c C-b, `q-inline-mode') works
;; unchanged.  The difference is in the input sender: what you send runs on
;; the remote server, and the result prints here at a wide console.
;;
;; Two prefixes route a send to the local q instead: `\' for a q system
;; command, and `kdb-local-prefix' (`%' by default), which is stripped.
;; `.kdb.last' in the local q holds the last remote result, so
;; `%select from .kdb.last where n>10' works on it without a round trip.
;;
;; `kdb-mode', a minor mode for .q buffers, remaps the q-mode eval keys to
;; commands that send the text as written.  q-mode's own commands drop blank
;; lines and fold indented lines with no space between, which merges the
;; statements of a query file and breaks a select that continues on an
;; indented line.  The driver splits statements the way the file reads: a
;; blank line or a comment line separates, an indented line continues.
;;
;; `kdb-targets' is empty here.  A site file sets it, along with
;; `kdb-query-directory' and `kdb-qhome' when the machine needs them.

;;; Code:

(require 'comint)
(require 'q-mode)

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

(defcustom kdb-query-directory nil
  "Directory where `kdb-save-query' writes files.
Nil prompts for the directory on every save."
  :type '(choice (const nil) directory)
  :group 'kdb)

(defcustom kdb-qhome nil
  "Value for the QHOME environment variable of the local q, or nil.
q reads its licence from QHOME.  Set this when the shell does not export it."
  :type '(choice (const nil) directory)
  :group 'kdb)

(defconst kdb-driver-file
  (expand-file-name "kdb-driver.q"
                    (file-name-directory (or load-file-name buffer-file-name)))
  "The q file the local process loads at start.")

(defvar-local kdb--target nil
  "The (NAME . PLIST) entry of `kdb-targets' this shell buffer talks to.")

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

(define-derived-mode kdb-shell-mode q-shell-mode "KDB"
  "Major mode for a local q shell that relays to a remote kdb server.
Derived from `q-shell-mode', so q-mode treats the buffer as a q shell."
  (setq-local comint-input-sender #'kdb--input-sender)
  (setq-local truncate-lines t))

(defun kdb--target-environment (name plist)
  "Return the process environment for a shell on target NAME with PLIST."
  (append (list "KX_LINE=0"
                (concat "KDB_NAME=" name)
                (concat "KDB_HOST=" (plist-get plist :host))
                (format "KDB_PORT=%s" (plist-get plist :port))
                (concat "KDB_USER=" (or (plist-get plist :user) "")))
          (when kdb-qhome
            (list (concat "QHOME=" (expand-file-name kdb-qhome))))
          process-environment))

;;;###autoload
(defun kdb-connect (name)
  "Open, or switch to, a shell on the `kdb-targets' entry NAME.
The shell becomes the active q buffer for the q-mode eval commands."
  (interactive
   (list (completing-read "KDB target: " (mapcar #'car kdb-targets) nil t)))
  (let* ((target (assoc name kdb-targets))
         (buffer (get-buffer-create (format "*kdb: %s*" name))))
    (unless target
      (user-error "No target named %s in `kdb-targets'" name))
    (unless (comint-check-proc buffer)
      (with-current-buffer buffer
        (kdb-shell-mode)
        (setq kdb--target target
              header-line-format (kdb--header-line)
              comint-input-ring-file-name (expand-file-name "~/.q_history"))
        (comint-read-input-ring t)
        (let ((process-environment (kdb--target-environment name (cdr target))))
          (comint-exec buffer "kdb" q-program nil (list kdb-driver-file)))
        (set-process-sentinel (get-buffer-process buffer) #'kdb--process-sentinel)))
    (q-activate-buffer buffer)
    (pop-to-buffer buffer)))

(defun kdb-reconnect ()
  "Open the remote handle of the active shell again."
  (interactive)
  (q-send-string (concat kdb-local-prefix ".kdb.connect[]")))

;;;; Eval commands

(defun kdb--active-p ()
  "Return non-nil when the active q buffer is a kdb shell."
  (and (buffer-live-p q-active-buffer)
       (buffer-local-value 'kdb--target q-active-buffer)))

(defun kdb-eval-region (start end)
  "Send the text between START and END, as written, to the active kdb shell.
When the active q buffer is a plain q shell, call `q-eval-region' instead."
  (interactive "r")
  (unless (and (buffer-live-p q-active-buffer) (comint-check-proc q-active-buffer))
    (user-error "No kdb shell is connected; run `kdb-connect' (C-c k c)"))
  (if (not (kdb--active-p))
      (q-eval-region start end)
    (q-send-string (buffer-substring-no-properties start end)
                   (cons (save-excursion (goto-char start) (line-beginning-position))
                         (save-excursion (goto-char end) (line-end-position))))
    (setq deactivate-mark t)))

(defun kdb-eval-line ()
  "Send the current line, as written, to the active kdb shell."
  (interactive)
  (kdb-eval-region (line-beginning-position) (line-end-position)))

(defun kdb-eval-buffer ()
  "Send the whole buffer, as written, to the active kdb shell."
  (interactive)
  (kdb-eval-region (point-min) (point-max)))

;;;; Saving a query

(defun kdb--slug-p (slug)
  "Return non-nil when SLUG is lower-case words joined by hyphens."
  (string-match-p "\\`[a-z0-9]+\\(-[a-z0-9]+\\)*\\'" slug))

(defun kdb-save-query (beg end slug purpose)
  "Save the region BEG..END, or the buffer, as a dated query file.
SLUG names the file, `YYYY-MM-DD-SLUG.q', under `kdb-query-directory'.
PURPOSE fills the first header line.  The file opens when written."
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
         (target (and (buffer-live-p q-active-buffer)
                      (buffer-local-value 'kdb--target q-active-buffer)))
         (text (buffer-substring-no-properties beg end)))
    (when (file-exists-p file)
      (user-error "%s exists" file))
    (make-directory dir t)
    (with-temp-file file
      (insert (format "/ purpose : %s\n" purpose)
              (format "/ env/db  : %s\n" (or (car target) ""))
              (format "/ ran     : %s\n" (format-time-string "%Y-%m-%d"))
              "/ result  : \n\n"
              (string-trim-right text) "\n"))
    (find-file file)
    (message "Saved %s" file)))

;;;; Keys

(defvar kdb-map
  (let ((map (make-sparse-keymap)))
    (define-key map "c" #'kdb-connect)
    (define-key map "r" #'kdb-reconnect)
    (define-key map "s" #'kdb-save-query)
    (define-key map "z" #'q-show-q-buffer)
    map)
  "Prefix keymap for the kdb commands.")
(fset 'kdb-map kdb-map)

(define-key kdb-shell-mode-map (kbd "C-c k") kdb-map)

(defvar kdb-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [remap q-eval-line] #'kdb-eval-line)
    (define-key map [remap q-eval-region] #'kdb-eval-region)
    (define-key map [remap q-eval-buffer] #'kdb-eval-buffer)
    (define-key map (kbd "C-c k") kdb-map)
    map)
  "Keymap for `kdb-mode'.")

;;;###autoload
(define-minor-mode kdb-mode
  "Send the q-mode eval keys as written when the active q buffer is a kdb shell.
\\{kdb-mode-map}"
  :lighter " KDB"
  :keymap kdb-mode-map)

(provide 'kdb)

;;; kdb.el ends here
