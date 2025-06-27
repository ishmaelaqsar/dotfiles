;;; init.el --- Personal configuration -*- lexical-binding: t -*-
;;; Commentary:
;;;

;; Add MELPA to package archives if not already added
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; Ensure use-package is installed
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

;; Configure use-package
(require 'use-package)
(setq use-package-always-ensure t) ;; Always ensure packages are installed
(setq use-package-verbose t)       ;; Show more information during loading

;; Keep .emacs.d clean with no-littering
(use-package no-littering
  :ensure t
  :config
  ;; Set paths for custom.el and auto-save files
  (setq custom-file (expand-file-name "custom.el" no-littering-etc-directory))
  ;; Keep auto-save files in var directory
  (setq auto-save-file-name-transforms
        `((".*" ,(expand-file-name "auto-save/" no-littering-var-directory) t)))
  ;; Load custom file if it exists
  (when (file-exists-p custom-file)
    (load custom-file)))

;; Fallback for custom-file if no-littering fails to load
(unless (featurep 'no-littering)
  (setq custom-file (expand-file-name "custom.el" user-emacs-directory))
  (when (file-exists-p custom-file)
    (load custom-file)))

;; UI Configuration
(use-package emacs
  :ensure nil
  :custom
  (font-use-system-font t)
  (window-resize-pixelwise t)
  (frame-resize-pixelwise t)
  (confirm-kill-emacs #'yes-or-no-p)
  :config
  ;; Load a custom theme
  (load-theme 'modus-operandi t)
  
  ;; Basic modes
  (save-place-mode t)
  (savehist-mode t)
  (recentf-mode t)
  
  ;; Set default major mode
  (setq-default major-mode
                (lambda () ; guess major mode from file name
                  (unless buffer-file-name
                    (let ((buffer-file-name (buffer-name)))
                      (set-auto-mode)))))
  
  ;; Convenience functions
  (defalias 'yes-or-no #'y-or-n-p))

;; Version control history as a tree
(use-package undo-tree
  :ensure t
  :bind
  (("C-x u" . undo-tree-visualize)
   ("C-/" . undo-tree-undo)
   ("C-?" . undo-tree-redo))
  :custom
  (undo-tree-auto-save-history t)
  :config
  ;; Set undo history directory based on whether no-littering loaded
  (setq undo-tree-history-directory-alist
        (if (featurep 'no-littering)
            `(("." . ,(expand-file-name "undo-tree-hist/" no-littering-var-directory)))
          `(("." . ,(expand-file-name "undo-tree-hist/" user-emacs-directory)))))
  (global-undo-tree-mode))

;; Programming mode configuration
(use-package prog-mode
  :ensure nil
  :hook
  (prog-mode . display-line-numbers-mode)
  (prog-mode . flymake-mode)
  (prog-mode . corfu-mode)
  (prog-mode . diff-hl-mode))

;; Electric pair mode
(use-package electric
  :ensure nil
  :config
  (electric-pair-mode t))

;; Completion framework
(use-package vertico
  :init
  (vertico-mode t)
  :config
  (define-key vertico-map (kbd "RET") #'vertico-directory-enter)
  (define-key vertico-map (kbd "DEL") #'vertico-directory-delete-word)
  (define-key vertico-map (kbd "M-d") #'vertico-directory-delete-char))

;; Rich annotations for minibuffer completions
(use-package marginalia
  :after vertico
  :ensure t
  :init
  (marginalia-mode)
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
  ;; Use consult to preview files and buffers
  (consult-preview-key 'any)
  ;; For more content-aware previewing
  (consult-preview-raw-size 8192)
  ;; Narrowing lets you restrict results to certain groups
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
  :ensure t
  :bind
  (("C-." . embark-act)        ;; pick some comfortable binding
   ("C-;" . embark-dwim)       ;; good alternative: M-.
   ("C-h B" . embark-bindings)) ;; alternative for `describe-bindings'
  :init
  ;; Replace the key help with a completing-read interface
  (setq prefix-help-command #'embark-prefix-help-command)
  :config
  ;; Hide the mode line of the Embark live/completions buffers
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 nil
                 (window-parameters (mode-line-format . none)))))

;; Embark-consult integration
(use-package embark-consult
  :after (embark consult)
  :ensure t
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

;; LSP Support
(use-package eglot)

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

;; DAP Support
(use-package dape
  :custom
  (dape-inlay-hints t)
  (dape-buffer-window-arrangement 'right))

;; Git client
(use-package magit
  :bind
  ("C-c g" . magit-status))

;; Indication of local VCS changes
(use-package diff-hl)

;; Programming language support
(use-package json-mode)
(use-package nasm-mode)
(use-package sly)
(use-package yaml-mode)
(use-package markdown-mode)

;; Outline-based notes management and organizer
(use-package org
  :ensure nil
  :bind
  ("C-c l" . org-store-link)
  ("C-c a" . org-agenda))

;; Additional Org-mode related functionality
(use-package org-contrib)

;; Org-roam - A plain-text personal knowledge management system
(use-package org-roam
  :ensure t
  :custom
  (org-roam-directory (file-truename "~/org-roam"))
  (org-roam-completion-everywhere t)
  (org-roam-capture-templates
   '(("d" "default" plain
      "%?"
      :if-new (file+head "%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n")
      :unnarrowed t)))
  :bind (("C-c r l" . org-roam-buffer-toggle)
         ("C-c r f" . org-roam-node-find)
         ("C-c r i" . org-roam-node-insert)
         ("C-c r c" . org-roam-capture)
         :map org-mode-map
         ("C-M-i" . completion-at-point))
  :config
  ;; If you're using a vertical completion framework, you might want a more informative completion interface
  (setq org-roam-node-display-template
        (concat "${title:*} " (propertize "${tags:10}" 'face 'org-tag)))
  (org-roam-db-autosync-mode))

;; Helpful - a better help system for Emacs
(use-package helpful
  :ensure t
  :bind
  ([remap describe-function] . helpful-callable)
  ([remap describe-variable] . helpful-variable)
  ([remap describe-key] . helpful-key)
  ("C-h F" . helpful-function)
  ("C-h C" . helpful-command)
  :config
  ;; Make C-h more helpful by showing both helpful and standard help
  (setq counsel-describe-function-function #'helpful-callable)
  (setq counsel-describe-variable-function #'helpful-variable))

;; IRC Client
(use-package rcirc
  :ensure nil
  :custom
  (rcirc-default-nick "ishmael-aqsar_jpmc")
  :hook
  (rcirc-mode . rcirc-track-minor-mode)
  (rcirc-mode . rcirc-omit-mode))

;; EditorConfig support
(use-package editorconfig
  :config
  (editorconfig-mode t))

;; In-Emacs Terminal Emulation
(use-package eat
  :custom
  (eat-kill-buffer-on-exit t)
  (eat-enable-mouse t))

;; Jump to arbitrary positions
(use-package avy
  :custom
  (avy-all-windows 'all-frames)
  :bind
  ("C-c z" . avy-goto-word-1))

;;; init.el ends here
