;;; early-init.el --- Runs before the package system and the first frame  -*- lexical-binding: t; -*-

;;; Commentary:

;; Two jobs. Keep the native-compilation cache out of ~/.config/emacs/, with
;; the other generated files; the redirect has to happen here, because Emacs
;; picks the cache directory before init.el loads. And take the repeated work
;; out of startup: garbage collection, file-name handlers and frame resizes,
;; none of which earn their cost while the init runs.

;;; Code:

(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (expand-file-name "emacs/eln-cache/"
                     (or (getenv "XDG_STATE_HOME") "~/.local/state/"))))

;; One autoload file for every package, instead of one per package.
;; setup-emacs.sh refreshes it after an install; so must M-x package-install.
;; The file is generated, so it lives with the other generated files.
(setopt package-quickstart t
        package-quickstart-file
        (expand-file-name "emacs/package-quickstart.el"
                          (or (getenv "XDG_STATE_HOME") "~/.local/state/")))

;; No collection during startup. The startup hook restores a threshold that
;; keeps pauses short in an editing session.
(setq gc-cons-threshold most-positive-fixnum)
(defvar my/file-name-handler-alist file-name-handler-alist
  "The handlers to restore after startup. Every `load' consults this list.")
(setq file-name-handler-alist nil)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024)
                  gc-cons-percentage 0.1
                  file-name-handler-alist my/file-name-handler-alist)))

;; The init changes faces and bars, and each change would resize the frame.
(setopt frame-inhibit-implied-resize t)
(push '(vertical-scroll-bars) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)

;;; early-init.el ends here
