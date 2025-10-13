;;; early-init.el --- Early initialization -*- lexical-binding: t -*-
;;; Commentary:
;;; Optimized early initialization for Emacs 28.2+ startup performance.

;;; Code:

;;;; 1. Package Initialization & GC Tuning (Performance)
;; =========================================================================

;; Maximize performance by preventing GC during startup (already in place)
(setq gc-cons-threshold most-positive-fixnum)
(setq gc-cons-percentage 0.6)

;; Explicitly disable package initialization early, as you're bootstrapping it in init.el.
(setq package-enable-at-startup nil)

;; Set a higher read process output max (default 4KB) for better external process performance.
(setq read-process-output-max (* 1024 1024)) ; 1MB

;; Faster font rendering (particularly on Windows)
(setq inhibit-compacting-font-caches t)

;; Resizing the Emacs frame can be a time-consuming process
(setq frame-inhibit-implied-resize t)

;;;; 2. UI Suppression (Aesthetics)
;; =========================================================================

;; Disable UI elements early to avoid momentary display during startup.
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(setq tool-bar-mode -1)
(setq scroll-bar-mode -1)

;; Suppress startup messages and splash screen.
(setq inhibit-splash-screen t)
(setq inhibit-startup-message t)
(setq inhibit-startup-echo-area-message user-login-name)

;;;; 3. Emacs 28+ Optimizations
;; =========================================================================

;; Faster minibuffer loading in Emacs 28+ (better integration with Vertico).
(setq read-extended-command-predicate #'command-completion-default-include-p)

;; Use native compilation if available (Emacs 28+)
(when (boundp 'native-comp-eln-load-path)
  (setq native-comp-async-report-warnings-errors 'silent)
  (setq native-comp-deferred-compilation t))

;; Set a better frame title that includes the file name
(setq frame-title-format
      '((:eval (if (buffer-file-name)
                   (abbreviate-file-name (buffer-file-name))
                  "%b"))))

;; Avoid unnecessary UTF-8 checks
(setq locale-coding-system 'utf-8)
(set-language-environment "UTF-8")
(set-default-coding-systems 'utf-8)

;;;; 4. Post-Startup Hooks (Cleanup)
;; =========================================================================

;; Reset GC parameters after startup is complete
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold 16777216)    ;; 16MB
            (setq gc-cons-percentage 0.1)))

;; Use fundamental-mode for initial scratch buffer for faster startup
(setq initial-major-mode 'fundamental-mode)

;; File name handler optimization cleanup (restored in init.el)
(setq file-name-handler-alist nil) ; Set nil here
(add-hook 'emacs-startup-hook      ; Restore the original in the hook
          (lambda ()
            (setq file-name-handler-alist efs/file-name-handler-alist-original)))

;; Stop Emacs from automatically checking if there are newer packages
(setq package-check-signature nil)

;;; early-init.el ends here
