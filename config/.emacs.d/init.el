;; This is only needed once, near the top of the file
(eval-when-compile
  (require 'package)
  (add-to-list 'package-archives
             '("melpa-stable" . "https://stable.melpa.org/packages/") t)
  (package-initialize)
  (unless (package-installed-p 'use-package)
    (package-refresh-contents)
    (package-install 'use-package))
  (require 'use-package)
  (setq use-package-always-ensure t))

(load-theme 'deeper-blue)
(setq font-lock-maximum-decoration 1)

(setq-default electric-indent-inhibit t) ; dont indent previous line on <RET>
(setq-default indent-tabs-mode nil) ; use spaces instead of tabs
(setq c-basic-offset 4)
(setq c-basic-indent 4)
(setq tab-stop-list (number-sequence 4 120 4))

(defalias 'perl-mode 'cperl-mode) ; always use cperl mode
(setq cperl-indent-level 4)
(setq cperl-indent-parens-as-block t)

(use-package magit)
(use-package which-key
  :config
  (which-key-mode))
