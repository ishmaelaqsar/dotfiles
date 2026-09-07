;;; bazel-tui-tests.el --- Tests for bazel-tui.el  -*- lexical-binding: t; -*-

;;; Commentary:

;; ERT tests of the pure functions in bazel-tui.el.  They run no engine and
;; open no window:
;;
;;   emacs --batch -Q -L . -l bazel-tui.el -l bazel-tui-tests.el \
;;     -f ert-run-tests-batch-and-exit
;;
;; init.el never loads this file.

;;; Code:

(require 'ert)
(require 'bazel-tui)

(ert-deftest bazel-tui-package-label-from-a-directory ()
  "The package of a directory is its path under the root, as a label prefix."
  (should (equal (bazel-tui--package-of "/ws/" "/ws/app/server/") "//app/server:"))
  (should (equal (bazel-tui--package-of "/ws" "/ws/app/server") "//app/server:"))
  (should (equal (bazel-tui--package-of "/ws/" "/ws/") "//:")))

(defun bazel-tui-tests--index (&rest pairs)
  "Return an index hash of LABEL CLASS PAIRS."
  (let ((index (make-hash-table :test #'equal)))
    (while pairs
      (puthash (pop pairs) (cons "kind" (pop pairs)) index))
    index))

(ert-deftest bazel-tui-only-a-selection-with-nothing-testable-is-refused ()
  "A mixed selection goes through; an alias and an unknown label go through;
only a selection made entirely of known non-tests is refused."
  (let ((index (bazel-tui-tests--index "//a:t" 'test "//a:lib" 'other "//a:bin" 'runnable "//a:al" 'unknown)))
    (should-not (bazel-tui--nothing-testable-p '("//a:t" "//a:lib") index))
    (should-not (bazel-tui--nothing-testable-p '("//a:al") index))
    (should-not (bazel-tui--nothing-testable-p '("//a/...") index))
    (should (bazel-tui--nothing-testable-p '("//a:lib" "//a:bin") index))))

(ert-deftest bazel-tui-candidates-follow-the-classes ()
  "The picker offers the classes asked for, sorted, or everything."
  (let ((index (bazel-tui-tests--index "//b:t" 'test "//a:lib" 'other "//a:bin" 'runnable)))
    (should (equal (bazel-tui--candidates index '(test unknown)) '("//b:t")))
    (should (equal (bazel-tui--candidates index '(runnable test)) '("//a:bin" "//b:t")))
    (should (equal (bazel-tui--candidates index nil) '("//a:bin" "//a:lib" "//b:t")))))

(ert-deftest bazel-tui-result-rows-put-the-failures-first ()
  "Aborts, then failed tests, then targets that did not build, then passes."
  (let* ((results '((aborts . (((label . "//x:gone") (reason . "ANALYSIS_FAILURE") (description . "no such target"))))
                    (tests . (((label . "//a:passes") (status . "PASSED") (passed . t) (duration_ms . 1500) (log . "/l/p"))
                              ((label . "//a:fails") (status . "FAILED") (passed . nil) (duration_ms . 250) (log . "/l/f") (xml . "/x/f"))))
                    (targets . (((label . "//a:passes") (success . t))
                                ((label . "//a:fails") (success . t))
                                ((label . "//a:broken") (success . nil))))))
         (rows (bazel-tui--result-rows results)))
    (should (equal (mapcar (lambda (row) (nth 2 row)) rows)
                   '("//x:gone" "//a:fails" "//a:broken" "//a:passes")))
    (should (equal (mapcar (lambda (row) (nth 7 row)) rows) '(t t t nil)))
    ;; The failed test carries its log and xml; the pass its log.
    (should (equal (nth 5 (nth 1 rows)) "/l/f"))
    (should (equal (nth 6 (nth 1 rows)) "/x/f"))
    (should (equal (nth 3 (nth 1 rows)) "0.2s"))))

(ert-deftest bazel-tui-a-failed-target-that-is-a-test-is-not-listed-twice ()
  "A test that failed to build is the test row, not also a did-not-build row."
  (let ((rows (bazel-tui--result-rows
               '((tests . (((label . "//a:t") (status . "FAILED_TO_BUILD") (passed . nil) (duration_ms . 0))))
                 (targets . (((label . "//a:t") (success . nil))))))))
    (should (= (length rows) 1))))

(ert-deftest bazel-tui-job-result-reads-the-summary-then-the-exit ()
  "A running job says nothing; a summary with counts is the counts; a summary
with an abort is the abort; a bare exit code is the code."
  (should (equal (bazel-tui--job-result '((state . "running"))) ""))
  (should (equal (bazel-tui--job-result '((state . "failed") (summary . ((passed . 3) (failed . 1)))))
                 "3 passed, 1 failed"))
  (should (equal (bazel-tui--job-result '((state . "failed") (summary . ((passed . 0) (failed . 0) (abort . "ANALYSIS_FAILURE")))))
                 "ANALYSIS_FAILURE"))
  (should (equal (bazel-tui--job-result '((state . "failed") (exit . 3))) "exit 3"))
  (should (equal (bazel-tui--job-result '((state . "failed") (error . "the job ended without a record of its exit")))
                 "the job ended without a record of its exit")))

(ert-deftest bazel-tui-took-is-short ()
  "The elapsed time reads in the unit that fits."
  (let ((t0 (encode-time '(0 0 12 1 1 2026 nil nil t))))
    (should (equal (bazel-tui--took t0 (time-add t0 2.5)) "2.5s"))
    (should (equal (bazel-tui--took t0 (time-add t0 125)) "2m05s"))
    (should (equal (bazel-tui--took t0 (time-add t0 3720)) "1h02m"))))

(ert-deftest bazel-tui-time-parses-what-the-engine-prints ()
  "RFC 3339 with fractions and offsets, as Go prints it, parses; junk is nil."
  (let ((utc (bazel-tui--time "2026-09-07T16:06:46.12Z"))
        (bst (bazel-tui--time "2026-09-07T17:06:46.12+01:00")))
    (should (time-equal-p utc bst))
    (should-not (bazel-tui--time "yesterday"))
    (should-not (bazel-tui--time nil))))

(ert-deftest bazel-tui-marks-are-carried-by-name-across-a-reprint ()
  "A mark held by name stays on its job when a new job shifts every row down."
  (with-temp-buffer
    (bazel-tui-jobs-mode)
    (let ((jobs (make-hash-table :test #'equal)))
      (dolist (name '("2" "1"))
        (puthash name `((name . ,name) (state . "succeeded") (label . ,name) (verb . "build")) jobs))
      (setq bazel-tui--jobs jobs
            tabulated-list-entries (mapcar (lambda (name) (bazel-tui--job-entry (gethash name jobs))) '("2" "1")))
      (tabulated-list-print t)
      (goto-char (point-min))
      (forward-line 1)
      (bazel-tui-jobs-mark)
      (should (equal bazel-tui--marks '("1")))
      ;; A newer job arrives at the top.
      (puthash "3" '((name . "3") (state . "running") (label . "3") (verb . "test")) jobs)
      (setq tabulated-list-entries (mapcar (lambda (name) (bazel-tui--job-entry (gethash name jobs))) '("3" "2" "1")))
      (tabulated-list-print t)
      (bazel-tui--apply-marks)
      (goto-char (point-min))
      (let (tagged)
        (while (not (eobp))
          (when (eq (char-after) ?*)
            (push (tabulated-list-get-id) tagged))
          (forward-line 1))
        (should (equal tagged '("1")))))))

(ert-deftest bazel-tui-wire-keeps-only-what-the-engine-reads ()
  "The wire form drops origin and source, and makes every list a vector."
  (let ((wire (bazel-tui--wire '((name . "x") (origin . "history") (source . "") (verb . "test")
                                 (targets . ("//a:t")) (flags . ()) (args . ("--p")) (env . ((K . "v")))))))
    (should (equal (alist-get 'name wire) "x"))
    (should-not (assq 'origin wire))
    (should (equal (alist-get 'targets wire) ["//a:t"]))
    (should (equal (alist-get 'args wire) ["--p"]))
    (should-not (assq 'flags wire))
    (should (equal (bazel-tui--json wire)
                   "{\"name\":\"x\",\"verb\":\"test\",\"targets\":[\"//a:t\"],\"args\":[\"--p\"],\"env\":{\"K\":\"v\"}}"))))

(ert-deftest bazel-tui-describe-matches-the-engine ()
  "An invocation is described as the engine's list describes it."
  (should (equal (bazel-tui--describe '((verb . "test") (targets . ("//a:t" "//a:u" "//a:v"))))
                 "test //a:t and 2 more"))
  (should (equal (bazel-tui--describe '((members . ("a" "b")))) "bundle of 2: a, b"))
  (should (equal (bazel-tui--describe '((error . "the entry has no name"))) "! the entry has no name")))

(provide 'bazel-tui-tests)

;;; bazel-tui-tests.el ends here
