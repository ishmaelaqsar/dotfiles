(setq font-lock-maximum-decoration 1)
(add-hook 'prog-mode-hook 'display-line-numbers-mode)

(setq-default electric-indent-inhibit t) ; dont indent previous line on <RET>
(setq-default indent-tabs-mode nil) ; use spaces instead of tabs
(setq c-basic-offset 4)
(setq c-basic-indent 4)
(setq tab-stop-list (number-sequence 4 120 4))

(defalias 'perl-mode 'cperl-mode) ; always use cperl mode
(setq cperl-indent-level 4)
(setq cperl-indent-parens-as-block t)
