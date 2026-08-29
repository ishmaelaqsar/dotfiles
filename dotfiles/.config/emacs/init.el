;;; init.el --- Emacs on the built-ins, plus a few packages  -*- lexical-binding: t; -*-

;;; Commentary:

;; Emacs 30 ships eglot, tree-sitter and use-package. This file configures
;; those, and adds five packages from MELPA: Sly for Common Lisp, Magit, and
;; the Vertico + Orderless + Consult search stack, which runs the installed
;; rg and fd from the minibuffer. setup-emacs.sh installs them from
;; `package-selected-packages'.
;;
;; eglot finds the language servers on PATH. The setup-*.sh scripts put them
;; there: clangd, basedpyright, gopls, jdtls. Nothing here names a server path.
;;
;; Generated files go under ~/.local/state/emacs/, so ~/.config/emacs/ holds
;; the tracked init and the package directory only. early-init.el sends the
;; native-compilation cache there as well.

;;; Code:

;;;; Packages

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(setopt package-selected-packages '(consult magit orderless sly vertico))

;; use-package is built in. Nothing here uses :ensure: the setup script
;; installs, and a missing package logs a warning instead of stopping the load.
;; After M-x package-install, run M-x package-quickstart-refresh, because
;; early-init.el turns package-quickstart on. M-x use-package-report measures
;; load times when a package feels slow.
(require 'use-package)

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
        ;; A language server answers in one chunk, not sixteen.
        read-process-output-max (* 1024 1024)
        ;; The async compiler logs its warnings instead of raising a window.
        native-comp-async-report-warnings-errors 'silent)

(savehist-mode 1)
(recentf-mode 1)
(save-place-mode 1)
(global-auto-revert-mode 1)
(delete-selection-mode 1)
(column-number-mode 1)
(electric-pair-mode 1)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'before-save-hook #'delete-trailing-whitespace)

;; A terminal frame draws a menu-bar line otherwise, so this is not GUI-only.
(menu-bar-mode -1)

(when (display-graphic-p)
  (tool-bar-mode -1)
  (scroll-bar-mode -1)
  ;; The family the terminal uses, and install.sh installs.
  (when (member "0xProto Nerd Font Mono" (font-family-list))
    (set-face-attribute 'default nil :family "0xProto Nerd Font Mono" :height 130)))

;;;; Terminal frames

;; emacsclient -t and emacs -nw. Ghostty and tmux both speak xterm, so the
;; xterm terminal init applies.
(xterm-mouse-mode 1)                    ; the default from Emacs 31
;; term/xterm.el loads when the first terminal frame opens, and reads these
;; right after. setSelection makes a kill reach the system clipboard through
;; OSC 52, which tmux (set-clipboard on) and ssh both forward. modifyOtherKeys
;; lets C-; and C-M-x reach Emacs. The default `check' asks the terminal, and
;; a terminal inside tmux does not answer.
(with-eval-after-load 'xterm
  (setopt xterm-set-window-title t
          xterm-extra-capabilities '(modifyOtherKeys setSelection)))

;;;; Completion: Vertico + Orderless + Consult

;; The minibuffer is the fuzzy picker, so fzf stays in the shell. Consult runs
;; the installed rg and fd, with a live preview, which is what telescope does
;; for Neovim.
(use-package vertico
  :init (vertico-mode 1))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  ;; Files complete on the path prefix first, or `~/.co' would match everything.
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package consult
  :bind (("C-x b"   . consult-buffer)
         ("M-y"     . consult-yank-pop)
         ("M-g g"   . consult-goto-line)
         ("M-g i"   . consult-imenu)
         ("M-s l"   . consult-line)
         ("M-s r"   . consult-ripgrep)
         ("M-s f"   . consult-fd)
         ("C-x C-r" . consult-recent-file)))

;;;; Search on rg

;; xref and M-x grep shell out to grep by default. install.sh puts rg on every
;; machine, so use it.
(setopt xref-search-program 'ripgrep)
(use-package grep
  :custom (grep-command "rg -nS --no-heading "))

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
fetches its grammar, and the mode is entered again with it in place.
Emacs 31 does this itself through `treesit-auto-install-grammar'; delete
this function when every machine runs 31."
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

(use-package eglot
  :hook ((c-ts-mode c++-ts-mode python-ts-mode go-ts-mode java-ts-mode) . eglot-ensure)
  :config
  ;; basedpyright is not in eglot's default table.
  (add-to-list 'eglot-server-programs
               '((python-mode python-ts-mode) . ("basedpyright-langserver" "--stdio"))))

;;;; Common Lisp

;; Sly loads Slynk through the Quicklisp that setup-sbcl.sh installs. :commands
;; defers it: nothing loads until the first M-x sly.
(use-package sly
  :commands (sly sly-connect)
  :custom (inferior-lisp-program "sbcl"))

;;;; Magit

(use-package magit
  :bind ("C-x g" . magit-status))

;;;; Server

(require 'server)
(unless (or noninteractive (server-running-p))
  (server-start))

;;; init.el ends here
