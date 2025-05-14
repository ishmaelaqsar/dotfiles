;;; early-init.el --- Early initialization -*- lexical-binding: t -*-
;;; Commentary:
;;; Early initialization file for Emacs 27+ to optimize startup

;;; Code:

;; Faster startup by inhibiting package.el initialization
(setq package-enable-at-startup nil)

;; Prevent loading package immediately after early-init.el
(setq package-quickstart nil)

;; Disable UI elements early to avoid momentary display during startup
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

;; Prevent the glimpse of un-styled Emacs by disabling these UI elements early
(tool-bar-mode -1)
(scroll-bar-mode -1)
(setq inhibit-splash-screen t)
(setq inhibit-startup-message t)
(setq inhibit-startup-echo-area-message user-login-name)

;; Maximize performance by preventing GC during startup
(setq gc-cons-threshold most-positive-fixnum)
(setq gc-cons-percentage 0.6)

;; Reset GC parameters after startup is complete
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold 16777216)    ;; 16MB
            (setq gc-cons-percentage 0.1)))

;; Use fundamental-mode for initial scratch buffer for faster startup
(setq initial-major-mode 'fundamental-mode)

;; Disable package.el in favor of straight.el (if you use it)
;; (setq package-enable-at-startup nil)

;; Faster font rendering (particularly on Windows)
(setq inhibit-compacting-font-caches t)

;; Use native compilation if available (Emacs 28+)
(when (boundp 'native-comp-eln-load-path)
  (setq native-comp-async-report-warnings-errors 'silent) ; Silence native-comp warnings
  (setq native-comp-deferred-compilation t))              ; Enable deferred compilation

;; Set a better frame title that includes the file name
(setq frame-title-format
      '((:eval (if (buffer-file-name)
                   (abbreviate-file-name (buffer-file-name))
                 "%b"))))

;; File name handler optimization
;; Temporarily disable the file name handler during startup
(defvar efs/file-name-handler-alist-original file-name-handler-alist)
(setq file-name-handler-alist nil)

;; Restore the file name handler after startup
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist efs/file-name-handler-alist-original)))

;; Set a higher read process output max to improve performance
(setq read-process-output-max (* 1024 1024)) ; 1MB (default is 4KB)

;; Resizing the Emacs frame can be a time-consuming process
(setq frame-inhibit-implied-resize t)

;; Avoid unnecessary UTF-8 checks
(setq locale-coding-system 'utf-8)
(set-language-environment "UTF-8")
(set-default-coding-systems 'utf-8)

;; Faster minibuffer loading in Emacs 28+
(when (>= emacs-major-version 28)
  (setq read-extended-command-predicate
        #'command-completion-default-include-p))

;; Stop Emacs from automatically checking if there are newer packages
(setq package-check-signature nil)

;;; early-init.el ends here
