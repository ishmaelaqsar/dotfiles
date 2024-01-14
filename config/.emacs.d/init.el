; theme
(add-to-list 'custom-theme-load-path "~/.emacs.d/themes/")
(if (daemonp)
    (add-hook 'after-make-frame-functions
        (lambda (frame)
            (select-frame frame)
            (load-theme 'nord t)))
    (load-theme 'nord t))

; font
(defun font-available-p (font-name)
  (find-font (font-spec :name font-name)))
(defun try-set-font ()
  (cond
   ((font-available-p "Iosevka Term")
    (add-to-list 'default-frame-alist '(font . "Iosevka Term-10")))
   ((font-available-p "DejaVu Sans Mono")
    (add-to-list 'default-frame-alist '(font . "DejaVu Sans Mono-11")))))
(if (daemonp)
    (add-hook 'after-make-frame-functions
              (lambda (frame)
                (select-frame frame)
                (try-set-font)))
  (try-set-font))

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
