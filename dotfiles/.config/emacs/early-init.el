;;; early-init.el --- Runs before the package system and the first frame  -*- lexical-binding: t; -*-

;;; Commentary:

;; One job: keep the native-compilation cache out of ~/.config/emacs/, with the
;; other generated files. The redirect has to happen here, because Emacs picks
;; the cache directory before init.el loads.

;;; Code:

(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (expand-file-name "emacs/eln-cache/"
                     (or (getenv "XDG_STATE_HOME") "~/.local/state/"))))

;;; early-init.el ends here
