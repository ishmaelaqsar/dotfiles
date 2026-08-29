;;; init.el --- Emacs on the built-ins, plus Sly and Magit  -*- lexical-binding: t; -*-

;;; Commentary:

;; Emacs 30 ships eglot, tree-sitter and use-package. This file configures
;; those, and adds the two packages that are not in core: Sly for Common Lisp
;; and Magit. setup-emacs.sh installs them from `package-selected-packages'.
;;
;; eglot finds the language servers on PATH. The setup-*.sh scripts put them
;; there: clangd, basedpyright, gopls, jdtls. Nothing here names a server path.
;;
;; Generated files go under ~/.local/state/emacs/, so ~/.config/emacs/ holds
;; the tracked init and the package directory only.

;;; Code:

;;;; Packages

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(setopt package-selected-packages '(sly magit))

;;;; Generated files

(defconst my/state-dir
  (expand-file-name "emacs/" (or (getenv "XDG_STATE_HOME") "~/.local/state/"))
  "Where Emacs writes what it generates: backups, auto-saves, custom-file.")
(make-directory my/state-dir t)

(setopt custom-file (expand-file-name "custom.el" my/state-dir))
(load custom-file 'noerror 'nomessage)

(setopt backup-directory-alist `(("." . ,(expand-file-name "backup/" my/state-dir)))
        auto-save-file-name-transforms `((".*" ,(expand-file-name "auto-save/" my/state-dir) t))
        auto-save-list-file-prefix (expand-file-name "auto-save-list/" my/state-dir)
        create-lockfiles nil
        recentf-save-file (expand-file-name "recentf" my/state-dir)
        savehist-file (expand-file-name "history" my/state-dir)
        save-place-file (expand-file-name "places" my/state-dir))

;;;; Defaults

(setopt inhibit-startup-screen t
        initial-scratch-message nil
        ring-bell-function #'ignore
        use-short-answers t
        indent-tabs-mode nil
        tab-width 4
        fill-column 100
        sentence-end-double-space nil
        require-final-newline t
        scroll-conservatively 101
        completion-styles '(basic partial-completion flex)
        completions-detailed t)

(savehist-mode 1)
(recentf-mode 1)
(save-place-mode 1)
(global-auto-revert-mode 1)
(delete-selection-mode 1)
(column-number-mode 1)
(electric-pair-mode 1)
(fido-vertical-mode 1)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'before-save-hook #'delete-trailing-whitespace)

(when (display-graphic-p)
  (menu-bar-mode -1)
  (tool-bar-mode -1)
  (scroll-bar-mode -1)
  ;; The family the terminal uses, and install.sh installs.
  (when (member "0xProto Nerd Font Mono" (font-family-list))
    (set-face-attribute 'default nil :family "0xProto Nerd Font Mono" :height 130)))

;;;; Tree-sitter

(require 'treesit)
(setopt treesit-language-source-alist
        '((bash "https://github.com/tree-sitter/tree-sitter-bash")
          (c "https://github.com/tree-sitter/tree-sitter-c")
          (cpp "https://github.com/tree-sitter/tree-sitter-cpp")
          (go "https://github.com/tree-sitter/tree-sitter-go")
          (gomod "https://github.com/camdencheek/tree-sitter-go-mod")
          (java "https://github.com/tree-sitter/tree-sitter-java")
          (json "https://github.com/tree-sitter/tree-sitter-json")
          (python "https://github.com/tree-sitter/tree-sitter-python")
          (toml "https://github.com/tree-sitter/tree-sitter-toml")
          (yaml "https://github.com/ikatyang/tree-sitter-yaml")))

(setopt major-mode-remap-alist
        '((sh-mode . bash-ts-mode)
          (c-mode . c-ts-mode)
          (c++-mode . c++-ts-mode)
          (c-or-c++-mode . c-or-c++-ts-mode)
          (go-mode . go-ts-mode)
          (java-mode . java-ts-mode)
          (js-json-mode . json-ts-mode)
          (python-mode . python-ts-mode)
          (conf-toml-mode . toml-ts-mode)
          (yaml-mode . yaml-ts-mode)))

(defun my/treesit-install-missing ()
  "Install the grammar of the current tree-sitter mode when it is absent.
A fresh machine then needs no manual step: the first file of a kind
fetches its grammar, and the mode is entered again with it in place."
  (pcase-let ((`(,lang . ,_) (assq (intern (string-remove-suffix "-ts-mode" (symbol-name major-mode)))
                                  treesit-language-source-alist)))
    (when (and lang (not (treesit-language-available-p lang)))
      (message "Installing the %s grammar..." lang)
      (treesit-install-language-grammar lang)
      (when (treesit-language-available-p lang)
        (funcall major-mode)))))

(dolist (mode '(bash-ts-mode c-ts-mode c++-ts-mode go-ts-mode java-ts-mode
                json-ts-mode python-ts-mode toml-ts-mode yaml-ts-mode))
  (add-hook (intern (format "%s-hook" mode)) #'my/treesit-install-missing))

;;;; eglot

(defvar eglot-server-programs)
(with-eval-after-load 'eglot
  ;; basedpyright is not in eglot's default table.
  (add-to-list 'eglot-server-programs
               '((python-mode python-ts-mode) . ("basedpyright-langserver" "--stdio"))))

(dolist (hook '(c-ts-mode-hook c++-ts-mode-hook python-ts-mode-hook
                go-ts-mode-hook java-ts-mode-hook))
  (add-hook hook #'eglot-ensure))

;;;; Common Lisp

(setopt inferior-lisp-program "sbcl")
;; Sly loads Slynk through the Quicklisp that setup-sbcl.sh installs.

;;;; Magit

(autoload 'magit-status "magit" nil t)
(global-set-key (kbd "C-x g") #'magit-status)

;;;; Server

(require 'server)
(unless (or noninteractive (server-running-p))
  (server-start))

;;; init.el ends here
