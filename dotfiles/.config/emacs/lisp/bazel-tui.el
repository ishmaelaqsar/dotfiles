;;; bazel-tui.el --- Drive Bazel through the bazel-tui engine  -*- lexical-binding: t; -*-

;; Package-Requires: ((emacs "30.1"))

;;; Commentary:

;; An Emacs front end for bazel-tui, the terminal interface for a large Bazel
;; workspace.  The engine is the `bazel-tui' binary: every command here runs it
;; with a subcommand and reads the JSON it prints.  Jobs are shared with the
;; terminal interface, because both read the same job directories: a job
;; started here is listed there, and one started there is killed here.
;;
;; The target browser is the minibuffer.  `bazel-tui-build', `bazel-tui-test',
;; `bazel-tui-run' and `bazel-tui-coverage' read targets from the cached index
;; with completion, defaulting to the package of the current buffer.  A prefix
;; argument asks for flags first.  `bazel-tui-deps', `bazel-tui-rdeps',
;; `bazel-tui-build-file' and `bazel-tui-cquery' are the drill-downs.  With
;; Embark, `C-.' on a target offers the same actions.
;;
;; `bazel-tui-jobs' lists every job in a `tabulated-list' that refreshes while
;; it is visible.  `RET' opens the log, `o' the results, `K' kills, `R'
;; restarts, `s' saves the job as an invocation, `i' sends a line to its input.
;; A log buffer follows a running job through `tail -F' and jumps to a
;; `file:line' with `compilation-minor-mode'.  Results come from the build
;; event stream: failures first, and `RET' on a test opens its log.
;;
;; `bazel-tui-invocations' picks one of the saved, remembered or IDE-defined
;; invocations and launches it; a bundle starts every member.  With Embark,
;; `e' amends the flags first, `s' saves it into the store, `d' deletes it.
;;
;; bazel.el, when installed, edits the BUILD files and supplies the error
;; regexp the log buffer uses.  Nothing here requires it.

;;; Code:

(require 'compile)
(require 'iso8601)
(require 'json)
(require 'tabulated-list)

(defgroup bazel-tui nil "Drive Bazel through the bazel-tui engine." :group 'tools)

(defcustom bazel-tui-program "bazel-tui"
  "The engine binary.  `make install' in the bazel-tui repository puts it on PATH."
  :type 'string
  :group 'bazel-tui)

(defcustom bazel-tui-jobs-refresh-seconds 2
  "How often a visible jobs buffer reads the jobs again."
  :type 'number
  :group 'bazel-tui)

(defface bazel-tui-ok-face '((t :inherit success))
  "Face of a job or a test that succeeded."
  :group 'bazel-tui)

(defface bazel-tui-bad-face '((t :inherit error))
  "Face of a job or a test that failed."
  :group 'bazel-tui)

(defface bazel-tui-running-face '((t :inherit warning))
  "Face of a job that is still running."
  :group 'bazel-tui)

(defvar bazel-tui-flags-history nil
  "History of the flags typed before a run.")

(defvar bazel-tui--last-job nil
  "The name of the job started most recently, for `bazel-tui-log-newest'.")

;;;; The engine

(defun bazel-tui--program ()
  "Return the engine binary, or say where it comes from."
  (or (executable-find bazel-tui-program)
      (user-error "%s is not on PATH; run make install in the bazel-tui repository"
                  bazel-tui-program)))

(defun bazel-tui--parse (text)
  "Parse TEXT, one JSON document, into alists and lists."
  (json-parse-string text :object-type 'alist :array-type 'list
                     :null-object nil :false-object nil))

(defun bazel-tui--first-line (text)
  "Return the first non-blank line of TEXT."
  (or (seq-find (lambda (line) (not (string-blank-p line))) (split-string text "\n"))
      "no output"))

(defun bazel-tui--call (input &rest args)
  "Run the engine with ARGS in the workspace of `default-directory'.
INPUT, when non-nil, is a string sent on stdin.  Return the parsed answer,
or signal `user-error' with the engine's own words."
  (let ((program (bazel-tui--program))
        (err-file (make-temp-file "bazel-tui-"))
        (dir (expand-file-name default-directory)))
    (unwind-protect
        (with-temp-buffer
          (let ((code (if input
                          (apply #'call-process-region input nil program nil (list t err-file) nil
                                 "-C" dir args)
                        (apply #'call-process program nil (list t err-file) nil "-C" dir args))))
            (unless (eq code 0)
              (user-error "bazel-tui %s: %s" (car args)
                          (bazel-tui--first-line
                           (with-temp-buffer (insert-file-contents err-file) (buffer-string)))))
            (bazel-tui--parse (buffer-string))))
      (delete-file err-file))))

(defun bazel-tui--start (callback input &rest args)
  "Run the engine with ARGS asynchronously, then call CALLBACK with the answer.
INPUT, when non-nil, is a string sent on stdin.  A failure is reported as a
message, with the engine's own words."
  (let* ((program (bazel-tui--program))
         (dir (expand-file-name default-directory))
         (stderr (generate-new-buffer " *bazel-tui stderr*"))
         (proc (make-process
                :name "bazel-tui"
                :buffer (generate-new-buffer " *bazel-tui*")
                :command `(,program "-C" ,dir ,@args)
                :stderr stderr
                :noquery t
                :sentinel
                (lambda (proc _event)
                  (when (memq (process-status proc) '(exit signal))
                    (let ((out (process-buffer proc)))
                      (unwind-protect
                          (if (eq (process-exit-status proc) 0)
                              (funcall callback
                                       (bazel-tui--parse (with-current-buffer out (buffer-string))))
                            (message "bazel-tui %s: %s" (car args)
                                     (bazel-tui--first-line
                                      (with-current-buffer stderr (buffer-string)))))
                        (kill-buffer out)
                        (kill-buffer stderr))))))))
    ;; The stderr pipe has a process of its own; keep it quiet.
    (let ((pipe (get-buffer-process stderr)))
      (set-process-sentinel pipe #'ignore)
      (set-process-query-on-exit-flag pipe nil))
    (when input
      (process-send-string proc input))
    (process-send-eof proc)
    proc))

(defun bazel-tui--json (alist)
  "Encode ALIST as the JSON the engine reads."
  (json-serialize alist :null-object nil :false-object :false))

;;;; The workspace

(defconst bazel-tui--markers '("MODULE.bazel" "WORKSPACE.bzlmod" "WORKSPACE.bazel" "WORKSPACE")
  "The files that mark a workspace root, as the engine looks for them.")

(defun bazel-tui--root ()
  "Return the workspace root of `default-directory', or signal."
  (or (locate-dominating-file
       default-directory
       (lambda (dir) (seq-some (lambda (m) (file-exists-p (expand-file-name m dir))) bazel-tui--markers)))
      (user-error "%s is not inside a Bazel workspace" (abbreviate-file-name default-directory))))

(defun bazel-tui--package-of (root dir)
  "Return the label prefix of the package at DIR under ROOT, `//app/server:'.
DIR is the directory that holds the BUILD file.  The root package is `//:'."
  (let ((rel (directory-file-name (file-relative-name dir root))))
    (if (member rel '("." ""))
        "//:"
      (concat "//" rel ":"))))

(defun bazel-tui--package-label ()
  "Return the label prefix of the package the current buffer is in, or nil."
  (when-let* ((root (ignore-errors (bazel-tui--root)))
              (dir (locate-dominating-file
                    default-directory
                    (lambda (d) (or (file-exists-p (expand-file-name "BUILD" d))
                                    (file-exists-p (expand-file-name "BUILD.bazel" d)))))))
    (when (string-prefix-p (expand-file-name root) (expand-file-name dir))
      (bazel-tui--package-of root dir))))

;;;; The index and the target picker

(defvar bazel-tui--indexes (make-hash-table :test #'equal)
  "The index of each workspace root: a hash of label to (KIND . CLASS).")

(defun bazel-tui--index (&optional refresh)
  "Return the index of the current workspace, loading it once.
With REFRESH, ask bazel again."
  (let ((root (bazel-tui--root)))
    (or (and (not refresh) (gethash root bazel-tui--indexes))
        (let* ((answer (if refresh (bazel-tui--call nil "index" "-refresh") (bazel-tui--call nil "index")))
               (table (make-hash-table :test #'equal :size (length (alist-get 'targets answer)))))
          (dolist (target (alist-get 'targets answer))
            (puthash (alist-get 'label target)
                     (cons (alist-get 'kind target) (intern (alist-get 'class target)))
                     table))
          (puthash root table bazel-tui--indexes)
          table))))

(defun bazel-tui-refresh-index ()
  "Ask bazel for the target index again."
  (interactive)
  (let ((index (bazel-tui--index t)))
    (message "bazel-tui: %d targets" (hash-table-count index))))

(defun bazel-tui--candidates (index classes)
  "Return the labels of INDEX whose class is in CLASSES, or every label."
  (let (labels)
    (maphash (lambda (label entry)
               (when (or (null classes) (memq (cdr entry) classes))
                 (push label labels)))
             index)
    (sort labels #'string<)))

(defun bazel-tui--target-table (index classes)
  "Return a completion table over the labels of INDEX in CLASSES.
The table carries the category `bazel-target', which is what Embark keys
its actions on, and an annotation of each target's kind."
  (let ((candidates (bazel-tui--candidates index classes)))
    (lambda (string predicate action)
      (if (eq action 'metadata)
          `(metadata (category . bazel-target)
                     (annotation-function
                      . ,(lambda (label)
                           (when-let* ((entry (gethash label index)))
                             (concat "  " (propertize (car entry) 'face 'completions-annotations))))))
        (complete-with-action action candidates string predicate)))))

(defun bazel-tui--read-targets (prompt classes)
  "Read one or more targets with PROMPT, offering the index's CLASSES.
The package of the current buffer is the initial input.  Return a list."
  (let ((table (bazel-tui--target-table (bazel-tui--index) classes)))
    (seq-remove #'string-empty-p
                (mapcar #'string-trim
                        (completing-read-multiple prompt table nil nil (bazel-tui--package-label))))))

(defun bazel-tui--read-target (prompt classes)
  "Read exactly one target with PROMPT, offering the index's CLASSES."
  (let ((label (string-trim
                (completing-read prompt (bazel-tui--target-table (bazel-tui--index) classes)
                                 nil nil (bazel-tui--package-label)))))
    (when (string-empty-p label)
      (user-error "No target given"))
    label))

(defun bazel-tui--read-flags (ask)
  "Return the flags to run with: none, or with ASK a list read from the minibuffer.
The string is split as a shell would, so a quoted flag stays one flag."
  (when ask
    (split-string-shell-command
     (read-string "Flags: " nil 'bazel-tui-flags-history))))

(defun bazel-tui--nothing-testable-p (labels index)
  "Return non-nil when no label in LABELS could be tested.
A label the index knows as a test or an alias is testable, and so is one the
index does not know, such as a pattern.  Only a selection made entirely of
known non-tests is refused, because bazel would build the lot and then say
it found no tests."
  (not (seq-some (lambda (label)
                   (let ((entry (gethash label index)))
                     (or (null entry) (memq (cdr entry) '(test unknown)))))
                 labels)))

(defun bazel-tui--launch (invocation)
  "Start INVOCATION, an alist the engine reads, and report it."
  (bazel-tui--start
   (lambda (answer)
     (setq bazel-tui--last-job (alist-get 'name answer))
     (message "bazel-tui: started %s" (alist-get 'name invocation))
     (bazel-tui--jobs-changed))
   (bazel-tui--json invocation)
   "start"))

(defun bazel-tui--invocation (verb targets flags)
  "Return the invocation alist for VERB on TARGETS with FLAGS."
  `((name . ,(concat verb " " (bazel-tui--summarise targets)))
    (verb . ,verb)
    (targets . ,(vconcat targets))
    (flags . ,(vconcat flags))))

(defun bazel-tui--summarise (targets)
  "Name TARGETS in the width a row has."
  (pcase (length targets)
    (0 "")
    (1 (car targets))
    (n (format "%s and %d more" (car targets) (1- n)))))

;;;###autoload
(defun bazel-tui-build (targets &optional flags)
  "Build TARGETS.  With a prefix argument, read FLAGS first."
  (interactive (list (bazel-tui--read-targets "bazel build: " nil)
                     (bazel-tui--read-flags current-prefix-arg)))
  (bazel-tui--launch (bazel-tui--invocation "build" targets flags)))

;;;###autoload
(defun bazel-tui-test (targets &optional flags)
  "Test TARGETS.  With a prefix argument, read FLAGS first.
A selection with nothing testable in it is refused before anything starts."
  (interactive (list (bazel-tui--read-targets "bazel test: " '(test unknown))
                     (bazel-tui--read-flags current-prefix-arg)))
  (when (bazel-tui--nothing-testable-p targets (bazel-tui--index))
    (user-error "Nothing in the selection is a test"))
  (bazel-tui--launch (bazel-tui--invocation "test" targets flags)))

;;;###autoload
(defun bazel-tui-coverage (targets &optional flags)
  "Run TARGETS under coverage.  With a prefix argument, read FLAGS first."
  (interactive (list (bazel-tui--read-targets "bazel coverage: " '(test unknown))
                     (bazel-tui--read-flags current-prefix-arg)))
  (when (bazel-tui--nothing-testable-p targets (bazel-tui--index))
    (user-error "Nothing in the selection is a test"))
  (bazel-tui--launch (bazel-tui--invocation "coverage" targets flags)))

;;;###autoload
(defun bazel-tui-run (target &optional flags)
  "Run TARGET, one runnable target.  With a prefix argument, read FLAGS first."
  (interactive (list (bazel-tui--read-target "bazel run: " '(runnable test unknown))
                     (bazel-tui--read-flags current-prefix-arg)))
  (bazel-tui--launch (bazel-tui--invocation "run" (list target) flags)))

;;;; Drill-downs

(defun bazel-tui--pick-among (prompt labels)
  "Offer LABELS with PROMPT, as targets, so an action can follow.
An empty list is the answer, and is said."
  (if (null labels)
      (message "bazel-tui: nothing")
    (let ((index (bazel-tui--index)))
      (completing-read prompt
                       (lambda (string predicate action)
                         (if (eq action 'metadata)
                             `(metadata (category . bazel-target)
                                        (annotation-function
                                         . ,(lambda (label)
                                              (when-let* ((entry (gethash label index)))
                                                (concat "  " (car entry))))))
                           (complete-with-action action labels string predicate)))
                       nil nil))))

;;;###autoload
(defun bazel-tui-deps (target)
  "Show what TARGET depends on directly, as a list to pick from."
  (interactive (list (bazel-tui--read-target "deps of: " nil)))
  (bazel-tui--pick-among (format "deps of %s: " target)
                         (alist-get 'labels (bazel-tui--call nil "deps" target))))

;;;###autoload
(defun bazel-tui-rdeps (target)
  "Show what depends on TARGET, as a list to pick from."
  (interactive (list (bazel-tui--read-target "rdeps of: " nil)))
  (bazel-tui--pick-among (format "rdeps of %s: " target)
                         (alist-get 'labels (bazel-tui--call nil "rdeps" target))))

;;;###autoload
(defun bazel-tui-build-file (target)
  "Open the BUILD file TARGET is declared in, at the rule."
  (interactive (list (bazel-tui--read-target "BUILD file of: " nil)))
  (let ((answer (bazel-tui--call nil "location" target)))
    (find-file (alist-get 'path answer))
    (goto-char (point-min))
    (forward-line (1- (alist-get 'line answer)))))

;;;###autoload
(defun bazel-tui-cquery (target)
  "Show how TARGET is configured."
  (interactive (list (bazel-tui--read-target "cquery: " nil)))
  (let ((lines (alist-get 'lines (bazel-tui--call nil "cquery" target)))
        (buffer (get-buffer-create (format "*bazel cquery: %s*" target))))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (string-join lines "\n") "\n"))
      (special-mode)
      (goto-char (point-min)))
    (pop-to-buffer buffer)))

;;;; Jobs

(defvar-local bazel-tui--jobs nil
  "In a jobs buffer, a hash of job name to the job alist the engine gave.")

(defvar-local bazel-tui--marks nil
  "In a jobs buffer, the names of the marked jobs.
Names, not rows: a new job shifts every row down, and a mark held by
position would slide onto whatever moved into that row.")

(defvar-local bazel-tui--timer nil
  "In a jobs buffer, the timer that refreshes it while it is visible.")

(defun bazel-tui--time (text)
  "Return the time TEXT names, RFC 3339 as the engine prints it, or nil."
  (when text
    (condition-case nil
        (encode-time (iso8601-parse text))
      (error nil))))

(defun bazel-tui--took (started ended)
  "Format the time from STARTED to ENDED, or to now when ENDED is nil."
  (let ((seconds (float-time (time-subtract (or ended (current-time)) started))))
    (cond ((< seconds 0) "")
          ((< seconds 60) (format "%.1fs" seconds))
          ((< seconds 3600) (format "%dm%02ds" (/ seconds 60) (mod (truncate seconds) 60)))
          (t (format "%dh%02dm" (/ seconds 3600) (mod (truncate (/ seconds 60)) 60))))))

(defun bazel-tui--job-result (job)
  "Return the one-line outcome of JOB, from its summary and its exit."
  (let ((summary (alist-get 'summary job))
        (state (alist-get 'state job))
        (err (alist-get 'error job)))
    (cond
     ((equal state "running") "")
     ((and err (not (string-empty-p err))) err)
     ((alist-get 'abort summary) (alist-get 'abort summary))
     ((and summary (or (> (alist-get 'passed summary 0) 0) (> (alist-get 'failed summary 0) 0)))
      (format "%d passed, %d failed" (alist-get 'passed summary) (alist-get 'failed summary)))
     ((alist-get 'exit_name summary) (alist-get 'exit_name summary))
     ((alist-get 'exit job) (format "exit %d" (alist-get 'exit job)))
     (t ""))))

(defun bazel-tui--state-face (state)
  "Return the face of a job in STATE."
  (pcase state
    ("running" 'bazel-tui-running-face)
    ("succeeded" 'bazel-tui-ok-face)
    (_ 'bazel-tui-bad-face)))

(defun bazel-tui--job-entry (job)
  "Return the `tabulated-list' entry of JOB."
  (let* ((state (alist-get 'state job))
         (started (bazel-tui--time (alist-get 'started job)))
         (ended (bazel-tui--time (alist-get 'ended job))))
    (list (alist-get 'name job)
          (vector (propertize state 'face (bazel-tui--state-face state))
                  (or (alist-get 'verb job) "")
                  (or (alist-get 'label job) "")
                  (if started (format-time-string "%m-%d %H:%M" started) "")
                  (if started (bazel-tui--took started ended) "")
                  (bazel-tui--job-result job)))))

(defun bazel-tui--fetch-jobs ()
  "Read the jobs of the current workspace into `bazel-tui--jobs'.
Return the entries for the list, newest first as the engine lists them."
  (let ((answer (bazel-tui--call nil "jobs"))
        (table (make-hash-table :test #'equal)))
    (dolist (job (alist-get 'jobs answer))
      (puthash (alist-get 'name job) job table))
    (setq bazel-tui--jobs table)
    (mapcar #'bazel-tui--job-entry (alist-get 'jobs answer))))

(defun bazel-tui--apply-marks ()
  "Draw the tag of every marked job."
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (when (member (tabulated-list-get-id) bazel-tui--marks)
        (tabulated-list-put-tag "*"))
      (forward-line 1))))

(defun bazel-tui-jobs-refresh (&rest _)
  "Read the jobs again and redraw, keeping point on the same job."
  (interactive)
  (setq tabulated-list-entries (bazel-tui--fetch-jobs))
  ;; A mark on a job that has been pruned is dropped with it.
  (setq bazel-tui--marks (seq-filter (lambda (name) (gethash name bazel-tui--jobs)) bazel-tui--marks))
  (tabulated-list-print t)
  (bazel-tui--apply-marks))

(defun bazel-tui--jobs-changed ()
  "Redraw every visible jobs buffer, after a start or a kill."
  (dolist (buffer (buffer-list))
    (when (and (buffer-live-p buffer)
               (eq (buffer-local-value 'major-mode buffer) 'bazel-tui-jobs-mode)
               (get-buffer-window buffer 'visible))
      (with-current-buffer buffer
        (ignore-errors (bazel-tui-jobs-refresh))))))

(defun bazel-tui--tick (buffer)
  "Refresh BUFFER when it is visible.  The timer calls this."
  (if (not (buffer-live-p buffer))
      (bazel-tui--stop-timer buffer)
    (when (get-buffer-window buffer 'visible)
      (with-current-buffer buffer
        (ignore-errors (bazel-tui-jobs-refresh))))))

(defun bazel-tui--stop-timer (&optional buffer)
  "Cancel the refresh timer of BUFFER, the current buffer by default."
  (with-current-buffer (or buffer (current-buffer))
    (when bazel-tui--timer
      (cancel-timer bazel-tui--timer)
      (setq bazel-tui--timer nil))))

(defun bazel-tui--start-timer ()
  "Start the refresh timer of the current jobs buffer."
  (bazel-tui--stop-timer)
  (setq bazel-tui--timer
        (run-with-timer bazel-tui-jobs-refresh-seconds bazel-tui-jobs-refresh-seconds
                        #'bazel-tui--tick (current-buffer))))

(defun bazel-tui-jobs-toggle-follow ()
  "Turn the automatic refresh of the jobs buffer off, or on again."
  (interactive)
  (if bazel-tui--timer
      (progn (bazel-tui--stop-timer) (message "bazel-tui: refresh off"))
    (bazel-tui--start-timer)
    (message "bazel-tui: refresh every %ss" bazel-tui-jobs-refresh-seconds)))

(defun bazel-tui--job-at-point ()
  "Return the job under point, or signal."
  (or (and (tabulated-list-get-id) (gethash (tabulated-list-get-id) bazel-tui--jobs))
      (user-error "No job here")))

(defun bazel-tui--chosen-jobs ()
  "Return the marked jobs, or the one under point when none are marked."
  (if bazel-tui--marks
      (mapcar (lambda (name) (gethash name bazel-tui--jobs)) bazel-tui--marks)
    (list (bazel-tui--job-at-point))))

(defun bazel-tui-jobs-mark ()
  "Mark the job under point and move down."
  (interactive)
  (let ((name (tabulated-list-get-id)))
    (when (and name (not (member name bazel-tui--marks)))
      (push name bazel-tui--marks)
      (tabulated-list-put-tag "*")))
  (forward-line 1))

(defun bazel-tui-jobs-unmark ()
  "Unmark the job under point and move down."
  (interactive)
  (let ((name (tabulated-list-get-id)))
    (setq bazel-tui--marks (delete name bazel-tui--marks))
    (tabulated-list-put-tag " "))
  (forward-line 1))

(defun bazel-tui-jobs-toggle-all ()
  "Mark every job, or unmark them all when every one is marked."
  (interactive)
  (let (all)
    (maphash (lambda (name _) (push name all)) bazel-tui--jobs)
    (setq bazel-tui--marks (if (= (length bazel-tui--marks) (length all)) nil all))
    (tabulated-list-print t)
    (bazel-tui--apply-marks)))

(defun bazel-tui-jobs-kill ()
  "Kill the marked jobs, or the one under point.
The escalation runs in the engine and takes the grace period, so this
returns at once and the rows read killed on a later refresh."
  (interactive)
  (let ((running (seq-filter (lambda (job) (equal (alist-get 'state job) "running"))
                             (bazel-tui--chosen-jobs))))
    (if (null running)
        (message "bazel-tui: nothing to kill")
      (when (or (= (length running) 1)
                (yes-or-no-p (format "Kill %d jobs? " (length running))))
        (apply #'bazel-tui--start
               (lambda (answer)
                 (message "bazel-tui: killed %d" (length (alist-get 'killed answer)))
                 (bazel-tui--jobs-changed))
               nil "kill" (mapcar (lambda (job) (alist-get 'name job)) running))
        (setq bazel-tui--marks nil)))))

(defun bazel-tui-jobs-restart ()
  "Run the job under point again, as a new job."
  (interactive)
  (let ((job (bazel-tui--job-at-point)))
    (bazel-tui--start
     (lambda (answer)
       (setq bazel-tui--last-job (alist-get 'name answer))
       (message "bazel-tui: restarted %s" (alist-get 'label job))
       (bazel-tui--jobs-changed))
     nil "restart" (alist-get 'name job))))

(defun bazel-tui-jobs-send (line)
  "Send LINE to the input of the job under point."
  (interactive (list (read-string (format "Send to %s: " (alist-get 'label (bazel-tui--job-at-point))))))
  (bazel-tui--call nil "send" (alist-get 'name (bazel-tui--job-at-point)) line)
  (message "bazel-tui: sent"))

(defun bazel-tui-jobs-save (name)
  "Save the job under point as an invocation called NAME."
  (interactive (list (read-string "Save as: " (alist-get 'label (bazel-tui--job-at-point)))))
  (bazel-tui--save (cons (cons 'name name)
                         (assq-delete-all 'name (copy-alist (alist-get 'invocation (bazel-tui--job-at-point)))))))

(defun bazel-tui-jobs-log ()
  "Open the log of the job under point."
  (interactive)
  (bazel-tui--open-log (bazel-tui--job-at-point)))

(defun bazel-tui-jobs-results ()
  "Open the results of the job under point."
  (interactive)
  (bazel-tui--open-results (bazel-tui--job-at-point)))

(defvar bazel-tui-jobs-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'bazel-tui-jobs-log)
    (define-key map "o" #'bazel-tui-jobs-results)
    (define-key map "K" #'bazel-tui-jobs-kill)
    (define-key map "R" #'bazel-tui-jobs-restart)
    (define-key map "s" #'bazel-tui-jobs-save)
    (define-key map "i" #'bazel-tui-jobs-send)
    (define-key map "m" #'bazel-tui-jobs-mark)
    (define-key map "u" #'bazel-tui-jobs-unmark)
    (define-key map "*" #'bazel-tui-jobs-toggle-all)
    (define-key map "f" #'bazel-tui-jobs-toggle-follow)
    (define-key map "g" #'bazel-tui-jobs-refresh)
    map)
  "Keymap for `bazel-tui-jobs-mode'.")

(define-derived-mode bazel-tui-jobs-mode tabulated-list-mode "Bazel-Jobs"
  "Major mode for the jobs of a workspace, newest first.
\\{bazel-tui-jobs-mode-map}"
  (setq tabulated-list-format
        [("State" 9 t) ("Verb" 8 t) ("Label" 44 t) ("Started" 11 t) ("Took" 8 nil) ("Result" 0 nil)]
        tabulated-list-padding 2
        tabulated-list-sort-key nil)
  (setq-local revert-buffer-function #'bazel-tui-jobs-refresh)
  (add-hook 'kill-buffer-hook #'bazel-tui--stop-timer nil t)
  (tabulated-list-init-header))

;;;###autoload
(defun bazel-tui-jobs ()
  "List the jobs of the current workspace."
  (interactive)
  (let* ((root (bazel-tui--root))
         (buffer (get-buffer-create (format "*bazel jobs: %s*" (file-name-nondirectory (directory-file-name root))))))
    (with-current-buffer buffer
      (unless (derived-mode-p 'bazel-tui-jobs-mode)
        (bazel-tui-jobs-mode))
      (setq default-directory root)
      (bazel-tui-jobs-refresh)
      (unless bazel-tui--timer
        (bazel-tui--start-timer)))
    (pop-to-buffer buffer)))

;;;###autoload
(defun bazel-tui-log-newest ()
  "Open the log of the newest job."
  (interactive)
  (let ((jobs (alist-get 'jobs (bazel-tui--call nil "jobs"))))
    (unless jobs
      (user-error "No jobs yet"))
    (bazel-tui--open-log (car jobs))))

;;;; The log

(defvar-local bazel-tui--log-job nil
  "In a log buffer, the job alist it shows.")

(defun bazel-tui--log-filter (proc text)
  "Insert TEXT from PROC at the end, keeping a window that was at the end there."
  (when-let* ((buffer (process-buffer proc)))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (let ((inhibit-read-only t)
              (at-end (= (point) (point-max)))
              (windows (seq-filter (lambda (w) (= (window-point w) (point-max)))
                                   (get-buffer-window-list buffer nil t))))
          (save-excursion
            (goto-char (point-max))
            (insert text))
          (when at-end (goto-char (point-max)))
          (dolist (w windows)
            (set-window-point w (point-max))))))))

(defun bazel-tui--stop-tail ()
  "Stop the tail process of the current log buffer, when there is one."
  (when-let* ((proc (get-buffer-process (current-buffer))))
    (set-process-sentinel proc #'ignore)
    (delete-process proc)))

(defun bazel-tui-log-kill ()
  "Kill the job this log belongs to."
  (interactive)
  (unless bazel-tui--log-job
    (user-error "This buffer follows no job"))
  (bazel-tui--start
   (lambda (answer)
     (message "bazel-tui: killed %d" (length (alist-get 'killed answer)))
     (bazel-tui--jobs-changed))
   nil "kill" (alist-get 'name bazel-tui--log-job)))

(defun bazel-tui-log-results ()
  "Open the results of the job this log belongs to."
  (interactive)
  (unless bazel-tui--log-job
    (user-error "This buffer follows no job"))
  (bazel-tui--open-results bazel-tui--log-job))

(defvar bazel-tui-log-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [remap kill-compilation] #'bazel-tui-log-kill)
    (define-key map (kbd "C-c C-k") #'bazel-tui-log-kill)
    (define-key map "o" #'bazel-tui-log-results)
    map)
  "Keymap for `bazel-tui-log-mode'.")

(define-derived-mode bazel-tui-log-mode special-mode "Bazel-Log"
  "Major mode for a job's log.
A `file:line' in the output is a link, through `compilation-minor-mode'.
\\{bazel-tui-log-mode-map}"
  (setq-local truncate-lines nil)
  (add-hook 'kill-buffer-hook #'bazel-tui--stop-tail nil t)
  (compilation-minor-mode 1))

;; bazel.el registers the `bazel' entry for bazel's own messages, which are
;; "ERROR: /path/BUILD:3:1: ...". Where it is not loaded, this stands in, with
;; the same shape.
(unless (assq 'bazel compilation-error-regexp-alist-alist)
  (add-to-list 'compilation-error-regexp-alist-alist
               `(bazel-tui
                 ,(rx bol (or "ERROR" (group "WARNING") (group (or "DEBUG" "INFO"))) ": "
                      (group (+ (any alnum ?/ ?- ?. ?_)) (or (seq "/BUILD" (? ".bazel")) ".bzl"))
                      ?: (group (+ digit)) ?: (group (+ digit)) ": ")
                 3 4 5 (1 . 2)))
  (add-to-list 'compilation-error-regexp-alist 'bazel-tui))

(defun bazel-tui--open-log (job)
  "Show the log of JOB, following it while the job runs."
  (let* ((name (alist-get 'name job))
         (log (alist-get 'log job))
         (running (equal (alist-get 'state job) "running"))
         (buffer (get-buffer-create (format "*bazel log: %s*" (alist-get 'label job))))
         (root default-directory))
    (with-current-buffer buffer
      (unless (and (derived-mode-p 'bazel-tui-log-mode)
                   (equal (alist-get 'name bazel-tui--log-job) name)
                   (or (get-buffer-process buffer) (not running)))
        (bazel-tui--stop-tail)
        (bazel-tui-log-mode)
        (setq bazel-tui--log-job job
              default-directory root)
        (let ((inhibit-read-only t))
          (erase-buffer)
          (when (file-exists-p (concat log ".1"))
            (insert (propertize "… earlier output was rotated away; see log.1 beside this log\n"
                                'face 'shadow)))
          (if running
              ;; tail -F follows the name, so the wrapper's rotation does not
              ;; end the stream.
              (make-process :name "bazel-tui-tail" :buffer buffer
                            :command (list "tail" "-n" "+1" "-F" log)
                            :filter #'bazel-tui--log-filter :sentinel #'ignore :noquery t)
            (when (file-exists-p log)
              (insert-file-contents log))
            (goto-char (point-max))))))
    (pop-to-buffer buffer)
    (goto-char (point-max))))

;;;; Results

(defvar-local bazel-tui--result-files nil
  "In a results buffer, a hash of row id to (LOG . XML) paths.")

(defun bazel-tui--result-rows (results)
  "Return the rows of RESULTS, failures first.
Each row is (ID STATUS LABEL TOOK DETAIL LOG XML BAD).  Aborts come first,
then failed tests, then targets that did not build, then passed tests."
  (let (rows)
    (dolist (abort (alist-get 'aborts results))
      (push (list (concat "abort " (alist-get 'label abort)) "abort" (alist-get 'label abort) ""
                  (concat (alist-get 'reason abort) ": " (alist-get 'description abort)) nil nil t)
            rows))
    (let ((tests (alist-get 'tests results)))
      (dolist (test tests)
        (unless (alist-get 'passed test)
          (push (bazel-tui--test-row test t) rows)))
      (dolist (target (alist-get 'targets results))
        (unless (or (alist-get 'success target)
                    (seq-find (lambda (test) (equal (alist-get 'label test) (alist-get 'label target))) tests))
          (push (list (concat "target " (alist-get 'label target)) "no build" (alist-get 'label target) ""
                      "did not build" nil nil t)
                rows)))
      (dolist (test tests)
        (when (alist-get 'passed test)
          (push (bazel-tui--test-row test nil) rows))))
    (nreverse rows)))

(defun bazel-tui--test-row (test bad)
  "Return the row of TEST, marked BAD when it did not pass."
  (list (concat "test " (alist-get 'label test))
        (downcase (alist-get 'status test))
        (alist-get 'label test)
        (format "%.1fs" (/ (alist-get 'duration_ms test 0) 1000.0))
        ""
        (alist-get 'log test)
        (alist-get 'xml test)
        bad))

(defun bazel-tui--result-entry (row)
  "Return the `tabulated-list' entry of ROW."
  (pcase-let ((`(,id ,status ,label ,took ,detail ,_log ,_xml ,bad) row))
    (list id (vector (propertize status 'face (if bad 'bazel-tui-bad-face 'bazel-tui-ok-face))
                     label took detail))))

(defun bazel-tui--result-file (which)
  "Return the WHICH path, `log' or `xml', of the row under point, or signal."
  (let ((files (and (tabulated-list-get-id) (gethash (tabulated-list-get-id) bazel-tui--result-files))))
    (or (if (eq which 'log) (car files) (cdr files))
        (user-error "This row has no %s" which))))

(defun bazel-tui-results-open-log ()
  "Open the test log of the row under point."
  (interactive)
  (find-file-read-only (bazel-tui--result-file 'log)))

(defun bazel-tui-results-open-xml ()
  "Open the test XML of the row under point."
  (interactive)
  (find-file-read-only (bazel-tui--result-file 'xml)))

(defvar bazel-tui-results-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'bazel-tui-results-open-log)
    (define-key map "x" #'bazel-tui-results-open-xml)
    map)
  "Keymap for `bazel-tui-results-mode'.")

(define-derived-mode bazel-tui-results-mode tabulated-list-mode "Bazel-Results"
  "Major mode for a job's decoded build events, failures first.
\\{bazel-tui-results-mode-map}"
  (setq tabulated-list-format [("Status" 10 t) ("Label" 50 t) ("Took" 8 nil) ("Detail" 0 nil)]
        tabulated-list-padding 1)
  (tabulated-list-init-header))

(defun bazel-tui--open-results (job)
  "Show the results of JOB."
  (let* ((results (bazel-tui--call nil "results" (alist-get 'name job)))
         (rows (bazel-tui--result-rows results))
         (buffer (get-buffer-create (format "*bazel results: %s*" (alist-get 'label job)))))
    (with-current-buffer buffer
      (unless (derived-mode-p 'bazel-tui-results-mode)
        (bazel-tui-results-mode))
      (setq bazel-tui--result-files (make-hash-table :test #'equal))
      (dolist (row rows)
        (puthash (car row) (cons (nth 5 row) (nth 6 row)) bazel-tui--result-files))
      (setq tabulated-list-entries (mapcar #'bazel-tui--result-entry rows))
      (setq header-line-format
            (format " %s  %d passed, %d failed%s"
                    (or (alist-get 'exit_name results) (if (alist-get 'done results) "" "no build events yet"))
                    (alist-get 'passed results 0) (alist-get 'failed results 0)
                    (let ((message (alist-get 'message results)))
                      (if (and message (not (string-empty-p message))) (concat "  " message) ""))))
      (tabulated-list-print t)
      (goto-char (point-min)))
    (pop-to-buffer buffer)))

;;;; Invocations

(defvar bazel-tui--invocations nil
  "The invocations offered by the last `bazel-tui-invocations', by name.")

(defun bazel-tui--describe (invocation)
  "Return the one-line summary of INVOCATION, as the engine's list shows it."
  (let ((members (alist-get 'members invocation))
        (err (alist-get 'error invocation)))
    (cond ((and err (not (string-empty-p err))) (concat "! " err))
          (members (format "bundle of %d: %s" (length members) (string-join members ", ")))
          (t (concat (alist-get 'verb invocation) " " (bazel-tui--summarise (alist-get 'targets invocation)))))))

(defun bazel-tui--invocation-table ()
  "Read every invocation and return a completion table over their names.
The table carries the category `bazel-invocation' for Embark, and annotates
each with its origin and what it runs."
  (let* ((answer (bazel-tui--call nil "invocations"))
         (table (make-hash-table :test #'equal))
         names)
    (dolist (problem (alist-get 'problems answer))
      (message "bazel-tui: %s" problem))
    (dolist (inv (alist-get 'invocations answer))
      (let ((name (alist-get 'name inv)))
        ;; First wins, so a duplicate name cannot shadow the entry the list
        ;; showed under it.
        (unless (gethash name table)
          (puthash name inv table)
          (push name names))))
    (setq bazel-tui--invocations table)
    (setq names (nreverse names))
    (lambda (string predicate action)
      (if (eq action 'metadata)
          `(metadata (category . bazel-invocation)
                     (display-sort-function . identity)
                     (annotation-function
                      . ,(lambda (name)
                           (when-let* ((inv (gethash name table)))
                             (concat "  " (propertize (format "%-7s" (alist-get 'origin inv)) 'face 'shadow)
                                     " " (bazel-tui--describe inv))))))
        (complete-with-action action names string predicate)))))

(defun bazel-tui--read-invocation (prompt)
  "Read the name of an invocation with PROMPT."
  (completing-read prompt (bazel-tui--invocation-table) nil t))

(defun bazel-tui--invocation-named (name)
  "Return the invocation called NAME from the last read, or signal."
  (or (and bazel-tui--invocations (gethash name bazel-tui--invocations))
      (user-error "%s names no invocation" name)))

;;;###autoload
(defun bazel-tui-invocations (name)
  "Launch the invocation called NAME; a bundle starts every member."
  (interactive (list (bazel-tui--read-invocation "Launch: ")))
  (bazel-tui--start
   (lambda (answer)
     (let ((dirs (alist-get 'dirs answer)))
       (setq bazel-tui--last-job (alist-get 'name (car (last dirs))))
       (message "bazel-tui: started %d from %s" (length dirs) name)
       (bazel-tui--jobs-changed)))
   nil "launch" name))

(defun bazel-tui-invocation-amend (name)
  "Start the invocation called NAME with its flags edited first."
  (interactive (list (bazel-tui--read-invocation "Amend and launch: ")))
  (let* ((inv (bazel-tui--invocation-named name)))
    (when (alist-get 'members inv)
      (user-error "%s is a bundle; amend its members" name))
    (let ((flags (split-string-shell-command
                  (read-string "Flags: " (combine-and-quote-strings (alist-get 'flags inv))
                               'bazel-tui-flags-history))))
      (bazel-tui--launch (bazel-tui--wire (cons (cons 'flags flags) (assq-delete-all 'flags (copy-alist inv))))))))

(defun bazel-tui-invocation-save (name)
  "Save the invocation called NAME into the workspace's store.
For an entry from the history or the IDE, this is how it is imported."
  (interactive (list (bazel-tui--read-invocation "Save: ")))
  (bazel-tui--save (bazel-tui--invocation-named name)))

(defun bazel-tui-invocation-delete (name)
  "Delete the saved invocation called NAME.  Only the store is written."
  (interactive (list (bazel-tui--read-invocation "Delete: ")))
  (let ((inv (bazel-tui--invocation-named name)))
    (unless (equal (alist-get 'origin inv) "saved")
      (user-error "%s is not in the saved store; only saved entries are deleted" name))
    (when (yes-or-no-p (format "Delete %s from the store? " name))
      (bazel-tui--call nil "delete" name)
      (message "bazel-tui: deleted %s" name))))

(defun bazel-tui--wire (invocation)
  "Return INVOCATION with only the fields the engine reads, lists as vectors."
  (let (out)
    (dolist (key '(name folder verb targets flags args env members))
      (when-let* ((value (alist-get key invocation)))
        (push (cons key (if (memq key '(targets flags args members)) (vconcat value) value)) out)))
    (nreverse out)))

(defun bazel-tui--save (invocation)
  "Write INVOCATION into the store and say so."
  (bazel-tui--call (bazel-tui--json (bazel-tui--wire invocation)) "save")
  (message "bazel-tui: saved %s" (alist-get 'name invocation)))

;;;; Keys and Embark

;; The keys sit outside the defvar, so a reload of this file updates them.
(defvar bazel-tui-map (make-sparse-keymap)
  "Prefix keymap for the bazel-tui commands.")
(define-key bazel-tui-map "b" #'bazel-tui-build)
(define-key bazel-tui-map "t" #'bazel-tui-test)
(define-key bazel-tui-map "x" #'bazel-tui-run)
(define-key bazel-tui-map "c" #'bazel-tui-coverage)
(define-key bazel-tui-map "j" #'bazel-tui-jobs)
(define-key bazel-tui-map "l" #'bazel-tui-log-newest)
(define-key bazel-tui-map "i" #'bazel-tui-invocations)
(define-key bazel-tui-map "r" #'bazel-tui-refresh-index)
(define-key bazel-tui-map "D" #'bazel-tui-deps)
(define-key bazel-tui-map "U" #'bazel-tui-rdeps)
(define-key bazel-tui-map "B" #'bazel-tui-build-file)
(define-key bazel-tui-map "C" #'bazel-tui-cquery)
(fset 'bazel-tui-map bazel-tui-map)

(defvar bazel-tui-target-map (make-sparse-keymap)
  "Embark actions on a target: the keys the terminal interface uses.")
(define-key bazel-tui-target-map "b" #'bazel-tui-build)
(define-key bazel-tui-target-map "t" #'bazel-tui-test)
(define-key bazel-tui-target-map "x" #'bazel-tui-run)
(define-key bazel-tui-target-map "c" #'bazel-tui-coverage)
(define-key bazel-tui-target-map "D" #'bazel-tui-deps)
(define-key bazel-tui-target-map "U" #'bazel-tui-rdeps)
(define-key bazel-tui-target-map "B" #'bazel-tui-build-file)
(define-key bazel-tui-target-map "C" #'bazel-tui-cquery)

(defvar bazel-tui-invocation-map (make-sparse-keymap)
  "Embark actions on an invocation.")
(define-key bazel-tui-invocation-map (kbd "RET") #'bazel-tui-invocations)
(define-key bazel-tui-invocation-map "e" #'bazel-tui-invocation-amend)
(define-key bazel-tui-invocation-map "s" #'bazel-tui-invocation-save)
(define-key bazel-tui-invocation-map "d" #'bazel-tui-invocation-delete)

(defvar embark-keymap-alist)
(with-eval-after-load 'embark
  (add-to-list 'embark-keymap-alist '(bazel-target . bazel-tui-target-map))
  (add-to-list 'embark-keymap-alist '(bazel-invocation . bazel-tui-invocation-map)))

(provide 'bazel-tui)

;;; bazel-tui.el ends here
