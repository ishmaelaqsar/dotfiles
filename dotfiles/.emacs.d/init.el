;; This is only needed once, near the top of the file
(eval-when-compile
  (require 'package)
  (add-to-list 'package-archives
               '("nongnu" . "https://elpa.nongnu.org/nongnu/"))
  (add-to-list 'package-archives
               '("melpa-stable" . "https://stable.melpa.org/packages/") t)
  (package-initialize)
  (unless (package-installed-p 'use-package)
    (package-refresh-contents)
    (package-install 'use-package))
  (require 'use-package)
  (setq use-package-always-ensure t))

;; Trigger GC when focus is lost
(setq gc-cons-threshold 100000000)
(add-function :after
              after-focus-change-function
              (lambda () (unless (frame-focus-state) (garbage-collect))))

; remember recently opened files
(recentf-mode 1)

(setq history-length 25)
;; remember minibuffer history
(savehist-mode 1)

;; remember and restore cursor location
(save-place-mode 1)

;; move customisation variables to a seperate file and load it
(setq custom-file (locate-user-emacs-file "custom-vars.el"))
(load custom-file 'noerror 'nomessage)

(tool-bar-mode 0)
(load-theme 'deeper-blue)
(setq font-lock-maximum-decoration 1)
(add-hook 'prog-mode-hook 'display-line-numbers-mode)

;; dont indent previous line on <RET>
(setq-default electric-indent-inhibit t)
;; use spaces instead of tabs
(setq-default indent-tabs-mode nil)
(setq c-basic-offset 4)
(setq c-basic-indent 4)
(setq tab-stop-list (number-sequence 4 120 4))

;; always use cperl mode
(defalias 'perl-mode 'cperl-mode)
(setq cperl-indent-level 4)
(setq cperl-indent-parens-as-block t)

;; initialise remote shells correctly
(let ((process-environment tramp-remote-process-environment))
  (setenv "ENV" "$HOME/.profile")
  (setq tramp-remote-process-environment process-environment))

(use-package eat)
(use-package magit)
(use-package which-key
  :config
  (which-key-mode))
(use-package vterm
  :ensure t)
