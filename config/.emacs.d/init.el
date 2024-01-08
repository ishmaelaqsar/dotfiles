; theme
(add-to-list 'default-frame-alist '(foreground-color . "black"))
(add-to-list 'default-frame-alist '(background-color . "light yellow"))

; font
(defun font-available-p (font-name)
  (find-font (font-spec :name font-name)))
(cond
 ((font-available-p "Iosevka Term")
  (set-frame-font "Iosevka Term-10"))
 ((font-available-p "DejaVu Sans Mono")
  (set-frame-font "DejaVu Sans Mono-11"))
 ((font-available-p "Unifont")
  (set-frame-font "Unifont-11")))

(global-font-lock-mode 0) ; turn off syntax highlighting
(add-hook 'prog-mode-hook 'display-line-numbers-mode)

(setq-default electric-indent-inhibit t) ; dont indent previous line on <RET>
(setq-default indent-tabs-mode nil) ; use spaces instead of tabs
(setq c-basic-offset 4)
(setq c-basic-indent 4)
(setq tab-stop-list (number-sequence 4 120 4))

(defalias 'perl-mode 'cperl-mode) ; always use cperl mode
(setq cperl-indent-level 4)
(setq cperl-indent-parens-as-block t)
