;;; init.el --- Personal configuration -*- lexical-binding: t -*-
;;; Commentary:
;;; A clean, modular configuration for a modern Emacs setup,
;;; relying on early-init.el for maximum startup optimization.

;;;; Package Management
;; =========================================================================

;; Add MELPA to package archives if not already added
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; Bootstrap 'use-package' (required since you disabled package-enable-at-startup)
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

;; Configure use-package
(require 'use-package)
(setq use-package-always-ensure t)
(setq use-package-verbose t)

;;;; Core Emacs Behavior & UI
;; =========================================================================

;; Keep .emacs.d clean with no-littering
(use-package no-littering
  :config
  ;; For a fully declarative config, remove the load/save custom-file logic.
  (setq custom-file (expand-file-name "custom.el" no-littering-etc-directory))
  (setq auto-save-file-name-transforms
        `((".*" ,(expand-file-name "auto-save/" no-littering-var-directory) t)))
  (setq undo-tree-history-directory-alist
      `(("." . ,(expand-file-name "undo-tree-hist/" no-littering-var-directory))))
  (when (file-exists-p custom-file)
    (load custom-file)))

;; Fallback for custom-file if no-littering fails to load
(unless (featurep 'no-littering)
  (setq custom-file (expand-file-name "custom.el" user-emacs-directory))
  (when (file-exists-p custom-file)
    (load custom-file)))

;; Theme Configuration
(use-package modus-themes
  :config
  (load-theme 'modus-operandi t))

;; Core UI and behavior tweaks
(use-package emacs
  :ensure nil
  :custom
  (font-use-system-font t)
  (window-resize-pixelwise t)
  (frame-resize-pixelwise t)
  (confirm-kill-emacs #'yes-or-no-p)
  :config
  (save-place-mode t)
  (savehist-mode t)
  (recentf-mode t)
  (setq-default major-mode
                (lambda ()
                  (unless buffer-file-name
                    (let ((buffer-file-name (buffer-name)))
                      (set-auto-mode)))))
  (defalias 'yes-or-no #'y-or-n-p))

;; Version control history as a tree
(use-package undo-tree
  :bind
  (("C-x u" . undo-tree-visualize)
   ("C-/" . undo-tree-undo)
   ("C-?" . undo-tree-redo))
  :custom
  (undo-tree-auto-save-history t)
  (undo-tree-history-management t)
  (undo-tree-history-directory-alist
   (if (featurep 'no-littering)
       `(("." . ,(expand-file-name "undo-tree-hist/" no-littering-var-directory)))
     `(("." . ,(expand-file-name "undo-tree-hist/" user-emacs-directory)))))
  :config
  (global-undo-tree-mode))

;;;; Completion Framework (Vertico, Consult, Marginalia, Embark)
;; =========================================================================

;; Minibuffer completion framework
(use-package vertico
  :init
  (vertico-mode t)
  :bind-keymap (:map vertico-map
                     ("RET" . vertico-directory-enter)
                     ("DEL" . vertico-directory-delete-word)
                     ("M-d" . vertico-directory-delete-char)))

;; Rich annotations for minibuffer completions
(use-package marginalia
  :after vertico
  :init (marginalia-mode)
  :custom
  (marginalia-annotators '(marginalia-annotators-heavy marginalia-annotators-light nil)))

;; Extended completion utilities
(use-package consult
  :after (vertico marginalia)
  :bind
  ([remap switch-to-buffer] . consult-buffer)
  ("C-c j" . consult-line)
  ("C-c i" . consult-imenu)
  :custom
  (consult-preview-key 'any)
  (consult-preview-raw-size 8192)
  (consult-narrow-key "<"))

;; Which-key - displays available keybindings
(use-package which-key
  :init
  (which-key-mode)
  :custom
  (which-key-idle-delay 0.5)
  (which-key-idle-secondary-delay 0.05))

;; Embark - context sensitive actions
(use-package embark
  :after marginalia
  :bind
  (("C-." . embark-act)
   ("C-;" . embark-dwim)
   ("C-h B" . embark-bindings))
  :init
  (setq prefix-help-command #'embark-prefix-help-command)
  :config
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 nil
                 (window-parameters (mode-line-format . none)))))

;; Embark-consult integration
(use-package embark-consult
  :after (embark consult)
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

;;;; Programming & Development
;; =========================================================================

;; General programming mode hooks
(use-package prog-mode
  :ensure nil
  :hook
  (prog-mode . display-line-numbers-mode)
  (prog-mode . flymake-mode)
  (prog-mode . corfu-mode)
  (prog-mode . diff-hl-mode))

;; Electric pair mode for auto-pairing delimiters
(use-package electric
  :ensure nil
  :config
  (electric-pair-mode t))

;; LSP Support
(use-package eglot
  :hook (prog-mode . eglot-ensure))

;; Inline static analysis
(use-package flymake
  :ensure nil
  :custom
  (help-at-pt-display-when-idle t)
  :bind (:map flymake-mode-map
              ("C-c n" . flymake-goto-next-error)
              ("C-c p" . flymake-goto-prev-error)))

;; Pop-up completion
(use-package corfu
  :custom
  (corfu-auto t))

;; DAP (Debug Adapter Protocol) Support
(use-package dape
  :custom
  (dape-inlay-hints t)
  (dape-buffer-window-arrangement 'right))

;; Git client
(use-package magit
  :bind ("C-c g" . magit-status))

;; Indication of local VCS changes in the fringe
(use-package diff-hl)

;; EditorConfig support
(use-package editorconfig
  :config (editorconfig-mode t))

;; Specific programming language support (consolidated)
(use-package (json-mode nasm-mode sly yaml-mode markdown-mode))


;;;; Org Mode & Personal Knowledge Management
;; =========================================================================
(use-package org
  :ensure nil
  :bind
  (("C-c c" . org-capture)
   ("C-c l" . org-store-link)
   ("C-c a" . org-agenda))
  :config
  (setq org-directory (file-truename "~/org"))
  (setq org-default-notes-file (expand-file-name "notes.org" org-directory))
  (setq org-agenda-files (directory-files-recursively org-directory "\\.org$"))
  (setq org-todo-file (expand-file-name "todo.org" org-directory))
  (setq org-journal-file (expand-file-name "journal.org" org-directory))
  (setq org-attach-id-directory (expand-file-name ".attach/" org-directory))
  (setq org-capture-templates
        `(("t" "Todo" entry
           (file+headline ,org-todo-file "Inbox")
           "* TODO %?\n  %U\n")
          ("s" "Scheduled Task" entry
           (file+headline ,org-todo-file "Scheduled")
           "* TODO %?\nSCHEDULED: %^T\n  %U\n")
          ("j" "Journal" entry
           (file+datetree ,org-journal-file)
           "* %?\nEntered on %U\n")))
  (setq org-agenda-custom-commands
        '(("d" "Daily Agenda & TODOs"
           ((agenda "" ((org-agenda-span 1)))
            (todo "TODO"
                  ((org-agenda-overriding-header "Unscheduled TODOs")))))
          ("w" "Weekly Overview"
           ((agenda "" ((org-agenda-span 7)))))))
  (org-clock-persistence-insinuate)
  (setq org-clock-persist 'history)
  (setq org-log-done 'time)
  (setq org-log-into-drawer t)
  (setq org-startup-indented t)
  (setq org-hide-leading-stars t)
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t) (shell . t) (python . t) (perl . t) (C . t) (org . t)))
  (setq org-confirm-babel-evaluate nil))

(use-package org-contrib)

(use-package org-roam
  :after org
  :custom
  (org-roam-directory (file-truename "~/org-roam"))
  (org-roam-completion-everywhere t)
  (org-roam-capture-templates
   '(("d" "default" plain
      "%?"
      :if-new (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n")
      :unnarrowed t)))
  (org-roam-node-display-template
   (concat "${title:*} " (propertize "${tags:10}" 'face 'org-tag)))
  :config
  (org-roam-db-autosync-mode)
  :bind (("C-c r l" . org-roam-buffer-toggle)
         ("C-c r f" . org-roam-node-find)
         ("C-c r i" . org-roam-node-insert)
         ("C-c r c" . org-roam-capture)
         :map org-mode-map
         ("C-M-i" . completion-at-point)))

;;;; Miscellaneous Tools
;; =========================================================================

(use-package helpful
  :bind
  ([remap describe-function] . helpful-callable)
  ([remap describe-variable] . helpful-variable)
  ([remap describe-key] . helpful-key)
  ("C-h F" . helpful-function)
  ("C-h C" . helpful-command))

(use-package rcirc
  :ensure nil
  :custom
  (rcirc-default-nick "ishmaelaqsar")
  :hook
  (rcirc-mode . rcirc-track-minor-mode)
  (rcirc-mode . rcirc-omit-mode))

(use-package eat
  :custom
  (eat-kill-buffer-on-exit t)
  (eat-enable-mouse t))

(use-package avy
  :custom
  (avy-all-windows 'all-frames)
  :bind
  ("C-c z" . avy-goto-word-1))


;;; init.el ends here
