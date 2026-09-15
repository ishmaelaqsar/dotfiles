;;; init.el --- Emacs on the built-ins, plus a few packages  -*- lexical-binding: t; -*-

;;; Commentary:

;; Emacs 30 and 31 ship eglot, tree-sitter and use-package. This file configures
;; those, and adds the packages that are not in core: Sly and paredit for Lisp,
;; Magit, markdown-mode, the Vertico + Orderless + Consult search stack, which
;; runs the installed rg and fd from the minibuffer, with Marginalia, Embark,
;; Avy, Corfu + Cape for completion at point, and eat for a bash inside a frame.
;; setup-emacs.sh installs them from `package-selected-packages'.
;;
;; eglot finds the language servers on PATH. The setup-*.sh scripts put them
;; there: clangd, basedpyright, gopls, jdtls. Nothing here names a server path.
;;
;; Generated files go under ~/.local/state/emacs/, so ~/.config/emacs/ holds
;; the tracked init and the package directory only. early-init.el sends the
;; native-compilation cache there as well.

;;; Code:

;;;; Generated files

(defconst my/state-dir
  (expand-file-name "emacs/" (or (getenv "XDG_STATE_HOME") "~/.local/state/"))
  "Where Emacs writes what it generates: backups, auto-saves, custom-file.")
(make-directory my/state-dir t)

;; custom.el loads before the Packages section, which then overrides the one
;; value package.el saves there: `package-selected-packages'.
(setopt custom-file (expand-file-name "custom.el" my/state-dir))
(load custom-file 'noerror 'nomessage)

(setopt backup-directory-alist `(("." . ,(expand-file-name "backup/" my/state-dir)))
        auto-save-file-name-transforms `((".*" ,(expand-file-name "auto-save/" my/state-dir) t))
        auto-save-list-file-prefix (expand-file-name "auto-save-list/" my/state-dir)
        create-lockfiles nil
        recentf-save-file (expand-file-name "recentf" my/state-dir)
        savehist-file (expand-file-name "history" my/state-dir)
        save-place-file (expand-file-name "places" my/state-dir)
        eshell-directory-name (expand-file-name "eshell/" my/state-dir))

;;;; Packages

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
;; Through Custom, not setopt: custom.el holds its saved value in the `user'
;; theme, and every `enable-theme' call (use-package and Modus both make one)
;; re-applies that theme. A Custom set replaces the theme value; setopt does
;; not, so its value would not survive the first `enable-theme'.
(customize-set-variable
 'package-selected-packages
 '(avy cape consult corfu dape eat embark embark-consult exec-path-from-shell
   magit marginalia markdown-mode orderless paredit q-mode sly vertico))

;; use-package is built in. Nothing here uses :ensure: the setup script
;; installs, and a missing package logs a warning instead of stopping the load.
;; After M-x package-install, run M-x package-quickstart-refresh, because
;; early-init.el turns package-quickstart on. M-x use-package-report measures
;; load times when a package feels slow.
(require 'use-package)

;; A daemon under launchd starts from launchd's environment, not the login
;; shell's, so eglot finds no language server and consult no rg or fd. This
;; copies PATH across, and KDB_QUERY_DIR, which kdb.el reads. A terminal frame
;; inherits the shell already, hence the guard.
(use-package exec-path-from-shell
  :if (or (daemonp) (memq window-system '(ns mac)))
  :custom
  (exec-path-from-shell-variables '("PATH" "MANPATH" "KDB_QUERY_DIR"))
  ;; A login shell, not an interactive one: .bash_profile sets the variables,
  ;; and .bashrc would add two seconds to the start.
  (exec-path-from-shell-arguments '("-l"))
  :config (exec-path-from-shell-initialize))

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
        native-comp-async-report-warnings-errors 'silent
        ;; A kill saves the clipboard to the ring first, so a copy from another
        ;; program survives it, and a kill never adds a duplicate entry.
        save-interprogram-paste-before-kill t
        kill-do-not-save-duplicates t
        ;; File notifications, not a poll every five seconds.
        auto-revert-avoid-polling t
        ;; find-file does not ping a word that looks like a host name.
        ffap-machine-p-known 'reject
        ;; A split rebalances its siblings.
        window-combination-resize t
        ;; Embark and Consult commands run from inside the minibuffer.
        enable-recursive-minibuffers t
        ;; TAB completes at point once the line is indented.
        tab-always-indent 'complete
        ;; The gutter does not jump at line 100.
        display-line-numbers-width 3
        show-paren-delay 0
        ;; The opening paren of an off-screen pair shows in an overlay.
        show-paren-context-when-offscreen 'overlay
        ;; Marks in the fringe at the top and the bottom of the buffer.
        indicate-buffer-boundaries 'left
        ;; Horizontal scroll from a trackpad tilt, in a graphical frame.
        mouse-wheel-tilt-scroll t
        mouse-wheel-flip-direction t
        ;; The project name in the mode line.
        project-mode-line t
        recentf-max-saved-items 200
        ;; With the *eldoc* buffer shown (C-h .), the echo area stays quiet.
        eldoc-echo-area-prefer-doc-buffer t
        ;; Compile output follows until the first error.
        compilation-scroll-output 'first-error)

;; Left-to-right text in every buffer: redisplay skips the bidirectional
;; analysis, which matters on long lines such as logs and JSON.
(setq-default bidi-paragraph-direction 'left-to-right)
(setq bidi-inhibit-bpa t)

(savehist-mode 1)
(recentf-mode 1)
(save-place-mode 1)
(global-auto-revert-mode 1)
(delete-selection-mode 1)
(column-number-mode 1)
(electric-pair-mode 1)
(minibuffer-depth-indicate-mode 1)
;; C-x o o o cycles windows, and C-x { { { resizes: the built-in repeat maps.
(repeat-mode 1)
;; C-c <left> restores the window layout a Magit or compile window replaced.
(winner-mode 1)
(global-hl-line-mode 1)
;; Grey text at point shows the first completion, and TAB accepts it. It is
;; the completion UI of a frame that cannot draw Corfu.
(global-completion-preview-mode 1)
;; Both are inert on a tty.
(pixel-scroll-precision-mode 1)
(context-menu-mode 1)
(blink-cursor-mode -1)
;; C-<arrows> move between windows, so C-<left> and C-<right> move windows, not
;; words; M-b and M-f move by word. tmux binds no C-<arrow>, so the keys reach
;; Emacs.
(windmove-default-keybindings 'control)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
;; Trailing whitespace shows in code, and M-x delete-trailing-whitespace
;; strips it. A save changes only the lines you edit.
(defun my/show-trailing-whitespace ()
  "Highlight trailing whitespace in this buffer."
  (setq show-trailing-whitespace t))
(add-hook 'prog-mode-hook #'my/show-trailing-whitespace)
;; Go, Bazel and cargo colour their output.
(add-hook 'compilation-filter-hook #'ansi-color-compilation-filter)

;; A terminal frame draws a menu-bar line otherwise, so this is not GUI-only.
(menu-bar-mode -1)

;; Modus ships with Emacs: dark, to match Ghostty and the GNOME colour scheme,
;; and every face pair clears WCAG AAA contrast. modus-operandi is its light
;; twin, and M-x modus-themes-toggle switches between the two.
;; Prose runs proportional, so org tables and source blocks lose their
;; alignment unless those faces keep a fixed pitch. Modus reads the option when
;; the theme loads, hence the order here.
(setopt modus-themes-to-toggle '(modus-vivendi modus-operandi)
        modus-themes-mixed-fonts t)
(load-theme 'modus-vivendi :no-confirm)

(defun my/apply-frame-settings (&optional frame)
  "Apply what depends on the frame: bars, font, and the theme's faces.
A daemon loads the init with no frame, so `display-graphic-p' is false
there and the theme's faces are computed for a dumb terminal. Every frame
`emacsclient' creates later needs this run for it."
  (with-selected-frame (or frame (selected-frame))
    (when (display-graphic-p)
      (tool-bar-mode -1)
      (scroll-bar-mode -1)
      ;; The family the terminal uses, and install.sh installs. `fixed-pitch'
      ;; needs it too: org tables and source blocks inherit that face, and its
      ;; own default asks for the generic "Monospace", which macOS answers with
      ;; Courier. Leave the height off, so it tracks `default'.
      (when (member "0xProto Nerd Font Mono" (font-family-list))
        (set-face-attribute 'default nil :family "0xProto Nerd Font Mono" :height 130)
        (set-face-attribute 'fixed-pitch nil :family "0xProto Nerd Font Mono")))
    (when (daemonp)
      (enable-theme 'modus-vivendi))))

(if (daemonp)
    (add-hook 'server-after-make-frame-hook #'my/apply-frame-settings)
  (my/apply-frame-settings))

;; Prose reads better in a proportional face. `variable-pitch' asks for the
;; generic family "Sans Serif", and each platform resolves that itself: macOS
;; answers Helvetica, Linux the fontconfig sans alias. So no font name belongs
;; here, and the two machines need no branch. A code buffer keeps the `default'
;; face, and stays 0xProto.
(add-hook 'text-mode-hook #'variable-pitch-mode)
;; Prose wraps at the window edge, and a wrapped line keeps the indent of its
;; list marker.
(add-hook 'text-mode-hook #'visual-line-mode)
(add-hook 'text-mode-hook #'visual-wrap-prefix-mode)

;;;; Terminal frames

;; emacsclient -t and emacs -nw. Ghostty and tmux both speak xterm, so the
;; xterm terminal init applies.
(xterm-mouse-mode 1)
;; term/xterm.el loads when the first terminal frame opens, and reads these
;; right after. setSelection makes a kill reach the system clipboard through
;; OSC 52, which tmux (set-clipboard on) and ssh both forward. modifyOtherKeys
;; is what asks for C-; and C-M-x. The default `check' asks the terminal, and a
;; terminal inside tmux does not answer, hence the explicit list. Asking is only
;; half of it: tmux drops the modifier unless `extended-keys' is on, which
;; tmux.conf sets.
(with-eval-after-load 'xterm
  (setopt xterm-set-window-title t
          xterm-extra-capabilities '(modifyOtherKeys setSelection)))

;;;; Dired

;; A copy or rename in one Dired window targets the other; a directory opens
;; in the same buffer; a revisit shows the current listing.
(use-package dired
  :custom
  (dired-dwim-target t)
  (dired-kill-when-opening-new-dired-buffer t)
  (dired-auto-revert-buffer t))

;;;; isearch

;; A match count in the prompt, and a search that survives C-a, C-e and a
;; scroll. C-r during a forward search goes to the previous match at once.
(use-package isearch
  :bind (:map isearch-mode-map
              ("C-." . isearch-forward-thing-at-point))
  :custom
  (isearch-lazy-count t)
  (lazy-count-prefix-format "(%s/%s) ")
  (isearch-allow-motion t)
  (isearch-allow-scroll t)
  (isearch-repeat-on-direction-change t)
  (isearch-wrap-pause 'no-ding))

;;;; Completion: Vertico + Orderless + Consult

;; The minibuffer is the fuzzy picker, so fzf stays in the shell. Consult runs
;; the installed rg and fd, with a live preview, which is what telescope does
;; for Neovim.
(use-package vertico
  :init (vertico-mode 1))

;; Edit a path by component: DEL deletes a whole directory at the end, and a
;; `~/' or `/' typed mid-path clears what it shadows.
(use-package vertico-directory
  :after vertico
  :bind (:map vertico-map
              ("RET"   . vertico-directory-enter)
              ("DEL"   . vertico-directory-delete-char)
              ("M-DEL" . vertico-directory-delete-word))
  :hook (rfn-eshadow-update-overlay . vertico-directory-tidy))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  ;; Files complete on the path prefix first, or `~/.co' would match everything.
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package consult
  :bind (("C-x b"   . consult-buffer)
         ("C-x p b" . consult-project-buffer)
         ("M-y"     . consult-yank-pop)
         ("M-g g"   . consult-goto-line)
         ("M-g i"   . consult-imenu)
         ("M-g o"   . consult-outline)
         ("M-g f"   . consult-flymake)
         ("M-s l"   . consult-line)
         ("M-s L"   . consult-line-multi)
         ("M-s r"   . consult-ripgrep)
         ("M-s f"   . consult-fd)
         ("C-x C-r" . consult-recent-file)
         ;; From isearch: M-e edits the search through its history, and M-s l
         ;; carries the search string into consult-line.
         :map isearch-mode-map
         ("M-e"   . consult-isearch-history)
         ("M-s l" . consult-line)
         ("M-s L" . consult-line-multi))
  :custom
  ;; < narrows the candidates to one group: b for buffers, f for files.
  (consult-narrow-key "<")
  ;; Debian and Ubuntu ship the binary as fdfind, which is why .aliases wraps
  ;; it. consult defaults to the literal "fd", so name whichever is here.
  (consult-fd-args
   (list (or (executable-find "fd") (executable-find "fdfind") "fd")
         "--full-path --color=never")))

;; Annotations beside every candidate: a docstring for a command, the size
;; and date of a file.
(use-package marginalia
  :init (marginalia-mode 1))

;; Act on the candidate or the thing at point. A prefix key, and a one-second
;; pause, lists the commands under it through the minibuffer; C-h after the
;; prefix lists them at once.
(use-package embark
  :demand t
  :bind (("C-."   . embark-act)
         ("C-;"   . embark-dwim)
         ("C-h B" . embark-bindings))
  :custom
  (prefix-help-command #'embark-prefix-help-command)
  (embark-auto-prefix-help-delay 1.0)
  :config (embark-auto-prefix-help-mode 1))

(use-package embark-consult
  :hook (embark-collect-mode . consult-preview-at-point-mode))

;; Jump to a visible position: M-j, then the characters you see there. In
;; isearch, M-j jumps to one of the matches. After M-j, `.' on a target runs
;; Embark there and leaves point where it is. C-M-j keeps
;; default-indent-new-line.
(defvar avy-ring)
(declare-function embark-act "embark")
(declare-function ring-ref "ring")

(defun my/avy-action-embark (pt)
  "Run `embark-act' at PT, then return to the window avy started from."
  (unwind-protect
      (save-excursion
        (goto-char pt)
        (embark-act))
    (select-window (cdr (ring-ref avy-ring 0))))
  t)

(use-package avy
  :bind (("M-j"   . avy-goto-char-timer)
         ("M-g l" . avy-goto-line)
         :map isearch-mode-map
         ("M-j" . avy-isearch))
  :config (setf (alist-get ?. avy-dispatch-alist) #'my/avy-action-embark))

;;;; Completion at point: Corfu + Cape

;; Corfu draws a child frame at point. A tty draws child frames from Emacs 31,
;; so on 30 a terminal frame keeps the built-in completion-at-point in the
;; minibuffer.
(defun my/corfu-maybe ()
  "Turn on `corfu-mode' where this frame can draw a child frame."
  (when (or (display-graphic-p) (>= emacs-major-version 31))
    (corfu-mode 1)))
(use-package corfu
  :hook ((prog-mode text-mode) . my/corfu-maybe)
  :bind (:map corfu-map
              ;; A space inside the popup separates Orderless terms.
              ("SPC" . corfu-insert-separator))
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.15)
  (corfu-auto-prefix 2)
  (corfu-cycle t))

;; The docstring of the selected candidate, beside the popup.
(use-package corfu-popupinfo
  :after corfu
  :hook (corfu-mode . corfu-popupinfo-mode)
  :custom (corfu-popupinfo-delay '(0.25 . 0.1)))

;; Extra completion sources: words in open buffers, and file paths.
(use-package cape
  :init
  (add-hook 'completion-at-point-functions #'cape-dabbrev)
  (add-hook 'completion-at-point-functions #'cape-file))

;;;; Search on rg

;; xref and M-x grep shell out to grep by default. install.sh puts rg on every
;; machine, so use it. Definitions and references pick in the minibuffer, with
;; a preview; consult-xref is autoloaded, so this holds before consult loads.
(setopt xref-search-program 'ripgrep
        xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)
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

;; Modes that have a classic twin are remapped to the tree-sitter one.
(setopt major-mode-remap-alist
        '((sh-mode . bash-ts-mode)
          (c-mode . c-ts-mode)
          (c++-mode . c++-ts-mode)
          (c-or-c++-mode . c-or-c++-ts-mode)
          (java-mode . java-ts-mode)
          (js-json-mode . json-ts-mode)
          (python-mode . python-ts-mode)
          (conf-toml-mode . toml-ts-mode)))

;; Go and YAML have no classic mode in Emacs, and their ts-modes register a
;; file association only when the grammar is already installed, so a fresh
;; machine would open .go in fundamental-mode. Register the associations here;
;; `my/treesit-install-missing' then fetches the grammar on the first file.
(dolist (entry '(("\\.go\\'" . go-ts-mode)
                 ("/go\\.mod\\'" . go-mod-ts-mode)
                 ("\\.ya?ml\\'" . yaml-ts-mode)))
  (add-to-list 'auto-mode-alist entry))

;; The mode name does not always match the grammar name (c++-ts-mode uses
;; cpp, go-mod-ts-mode uses gomod), so the pairs are explicit rather than
;; derived from the mode name.
(defconst my/treesit-mode-languages
  '((bash-ts-mode . bash) (c-ts-mode . c) (c++-ts-mode . cpp)
    (go-ts-mode . go) (go-mod-ts-mode . gomod) (java-ts-mode . java)
    (json-ts-mode . json) (python-ts-mode . python) (toml-ts-mode . toml)
    (yaml-ts-mode . yaml))
  "The grammar language of each tree-sitter mode this config uses.")

;; A missing grammar installs itself on the first file of its kind, so a fresh
;; machine needs no manual step. Emacs 31 does this through
;; `treesit-auto-install-grammar'; on 30 `my/treesit-install-missing' does it.
(defun my/treesit-install-missing ()
  "Install the grammar of the current tree-sitter mode when it is absent,
then enter the mode again with the grammar in place."
  (let ((lang (alist-get major-mode my/treesit-mode-languages)))
    (when (and lang (not (treesit-language-available-p lang)))
      (message "Installing the %s grammar..." lang)
      (treesit-install-language-grammar lang)
      (when (treesit-language-available-p lang)
        (funcall major-mode)))))

(if (boundp 'treesit-auto-install-grammar)
    (setopt treesit-auto-install-grammar 'always)
  (dolist (pair my/treesit-mode-languages)
    (add-hook (intern (format "%s-hook" (car pair))) #'my/treesit-install-missing)))

;;;; eglot

(use-package eglot
  :hook ((c-ts-mode c++-ts-mode python-ts-mode go-ts-mode java-ts-mode) . eglot-ensure)
  :custom
  ;; eglot manages a file that xref opens outside the project, such as a
  ;; header under /usr/include.
  (eglot-extend-to-xref t)
  ;; No events log. Set :size to a number to debug a server.
  (eglot-events-buffer-config '(:size 0))
  :config
  ;; basedpyright is not in eglot's default table.
  (add-to-list 'eglot-server-programs
               '((python-mode python-ts-mode) . ("basedpyright-langserver" "--stdio"))))

;;;; Diagnostics

;; A diagnostic shows at the end of its line, M-n and M-p walk them, and
;; M-g f lists them. The end-of-line option takes t on Emacs 30 and 31 both.
(use-package flymake
  :bind (:map flymake-mode-map
              ("M-n" . flymake-goto-next-error)
              ("M-p" . flymake-goto-prev-error))
  :custom (flymake-show-diagnostics-at-end-of-line t))

;;;; Format on save through the language server

;; gopls, jdtls and clangd implement textDocument/formatting, so any buffer
;; whose server reports the capability formats before a save; Go also gets its
;; imports organised first, which is what goimports does. basedpyright reports
;; no such capability, so Python stays with ruff. jdtls needs no
;; profile: eglot sends tab-width and indent-tabs-mode as the formatting
;; options, so Java gets 4 spaces from `tab-width'; a project that
;; wants a style ships its own java.format.settings.url.
(declare-function eglot-managed-p "eglot")
(declare-function eglot-server-capable "eglot")
(declare-function eglot-format-buffer "eglot")
(declare-function eglot-code-action-organize-imports "eglot")

;; A directory-local nil turns the save hooks off, for a shared repository
;; whose diffs must stay small. lisp/site.el sets it per directory, and C-c f
;; formats on demand either way.
(defvar-local my/format-on-save t
  "Whether a save formats this buffer through eglot or ruff.")
(put 'my/format-on-save 'safe-local-variable #'booleanp)

(defun my/eglot-format-buffer ()
  "Organize the imports where the server does that, then format the buffer."
  (when (derived-mode-p 'go-ts-mode)
    (ignore-errors (eglot-code-action-organize-imports (point-min) (point-max))))
  (eglot-format-buffer))

(defun my/eglot-format-before-save ()
  "Format the buffer through eglot when `my/format-on-save' is on."
  (when my/format-on-save (my/eglot-format-buffer)))

(defun my/eglot-format-on-save ()
  "Add or remove the save hook as eglot starts or stops managing this buffer."
  (if (and (eglot-managed-p) (eglot-server-capable :documentFormattingProvider))
      (add-hook 'before-save-hook #'my/eglot-format-before-save nil t)
    (remove-hook 'before-save-hook #'my/eglot-format-before-save t)))
(add-hook 'eglot-managed-mode-hook #'my/eglot-format-on-save)

;;;; Python formatting: ruff

;; basedpyright checks types and completes, and formats nothing: pyright does not
;; implement textDocument/formatting. ruff is the formatter, installed as a
;; uv tool by setup-python.sh, so run it on save: first the import sorter
;; (rule set I, the isort rules), then the formatter, the order ruff itself
;; documents. replace-buffer-contents keeps point and marks in place.
(defun my/ruff--pipe (args)
  "Pipe the buffer through ruff with ARGS. Return the output buffer, or nil."
  (let ((out (generate-new-buffer " *ruff*")))
    (if (zerop (apply #'call-process-region (point-min) (point-max) "ruff" nil out nil args))
        out
      (kill-buffer out)
      nil)))

(defun my/ruff-format-buffer ()
  "Sort the imports and format the buffer with ruff, when ruff is on PATH."
  (when (executable-find "ruff")
    (let ((file (or (buffer-file-name) "stdin.py")))
      (dolist (args `(("check" "--fix" "--select" "I" "--quiet" "--stdin-filename" ,file "-")
                      ("format" "--stdin-filename" ,file "-")))
        (let ((out (my/ruff--pipe args)))
          (when out
            (replace-buffer-contents out)
            (kill-buffer out)))))))

(defun my/ruff-format-before-save ()
  "Format the buffer with ruff when `my/format-on-save' is on."
  (when my/format-on-save (my/ruff-format-buffer)))

(defun my/ruff-format-on-save ()
  "Format with ruff before this buffer is saved."
  (add-hook 'before-save-hook #'my/ruff-format-before-save nil t))
(add-hook 'python-ts-mode-hook #'my/ruff-format-on-save)
(add-hook 'python-mode-hook #'my/ruff-format-on-save)

;; C-c f formats the buffer on demand: through eglot where the server formats,
;; through ruff in a Python buffer.
(defun my/format-buffer ()
  "Format this buffer through eglot or ruff."
  (interactive)
  (cond ((and (featurep 'eglot) (eglot-managed-p)
              (eglot-server-capable :documentFormattingProvider))
         (my/eglot-format-buffer))
        ((derived-mode-p 'python-mode 'python-ts-mode)
         (my/ruff-format-buffer))
        (t (message "No formatter for %s" major-mode))))
(keymap-global-set "C-c f" #'my/format-buffer)

;;;; Debugging: Dape

;; A DAP client: breakpoints in the margin, locals and a REPL in side windows.
;; gud's M-x gdb and M-x lldb stay for the text-only route. Adapters: gdb's own
;; `-i dap' on Linux (gdb 14 or newer, which setup-c.sh installs), and lldb-dap,
;; which Xcode ships outside PATH on macOS, hence xcrun.
;; The keys live on C-c because gud.el runs
;; (global-set-key gud-key-prefix gud-global-map) when it loads, and its prefix
;; is C-x C-a. A binding there disappears with the first M-x gdb.
(use-package dape
  :commands (dape dape-breakpoint-toggle)
  :bind (("C-c d" . dape)
         ("C-c b" . dape-breakpoint-toggle))
  :custom
  (dape-buffer-window-arrangement 'right)
  (dape-inlay-hints t)
  :config
  (when (and (eq system-type 'darwin) (not (executable-find "lldb-dap")))
    (let ((cfg (alist-get 'lldb-dap dape-configs)))
      (plist-put cfg 'command "xcrun")
      (plist-put cfg 'command-args '("lldb-dap"))))
  ;; debugpy is a uv tool in its own venv, so `python -m debugpy.adapter', the
  ;; default, finds no module. The tool installs debugpy-adapter on PATH: run it.
  (when (executable-find "debugpy-adapter")
    (let ((cfg (alist-get 'debugpy dape-configs)))
      (plist-put cfg 'command "debugpy-adapter")
      ;; Loopback only: the adapter evaluates arbitrary expressions in the
      ;; debuggee, so a wildcard bind hands that to the whole network.
      (plist-put cfg 'command-args '("--host" "127.0.0.1" "--port" :autoport)))))

;;;; Common Lisp

;; Sly loads Slynk through the Quicklisp that setup-sbcl.sh installs. :commands
;; defers it: nothing loads until the first M-x sly.
(use-package sly
  :commands (sly sly-connect)
  :custom (inferior-lisp-program "sbcl"))

;; Structural editing for Lisp: a delimiter always has its pair, and the sexp
;; commands slurp, barf and raise. M-s stays the search prefix, and C-c s
;; splices. paredit inserts its own pairs, so electric-pair is off in these
;; buffers.
(defvar paredit-mode-map)
(declare-function paredit-splice-sexp "paredit")

(defun my/paredit-no-electric-pair ()
  "Turn `electric-pair-local-mode' off; paredit pairs the delimiters."
  (electric-pair-local-mode -1))
(use-package paredit
  ;; Only once installed: package.el opens paredit's own files in
  ;; emacs-lisp-mode while it generates their autoloads, and the mode hook
  ;; would call a paredit that is not loadable yet.
  :if (locate-library "paredit")
  :hook (((lisp-mode emacs-lisp-mode lisp-interaction-mode sly-mrepl-mode) . paredit-mode)
         (paredit-mode . my/paredit-no-electric-pair))
  :config
  (keymap-unset paredit-mode-map "M-s" t)
  (keymap-set paredit-mode-map "C-c s" #'paredit-splice-sexp))

;;;; Magit

;; C-x t g in tmux opens magit in a popup, in a frame made for that one job.
;; The tools menu calls `my/magit-popup', which marks the frame, and `q'
;; deletes a marked frame rather than leaving it on *scratch*. A magit buffer
;; reached any other way buries, because no other frame carries the mark.
(defun my/magit-popup ()
  "Open `magit-status' in a frame that `q' may close."
  (interactive)
  (set-frame-parameter nil 'my-magit-popup t)
  (magit-status))

(defun my/magit-bury-buffer (kill-buffer)
  "Close the tmux popup frame, or bury the buffer as magit normally does."
  (if (frame-parameter nil 'my-magit-popup)
      (delete-frame)
    (magit-mode-quit-window kill-buffer)))

(use-package magit
  :bind ("C-x g" . magit-status)
  :custom (magit-bury-buffer-function #'my/magit-bury-buffer))

;;;; Shells

;; In a tty frame, tmux is the terminal: M-n splits and M-f pops a shell. A GUI
;; frame (ce, alt+shift+o, VISUAL) has no tmux, so the shells live here.
;; eshell is the Lisp shell, on C-x p e. Its full-screen commands run in eat,
;; not in term.el.
;; em-term holds the list, and loads with the first eshell.
(use-package em-term
  :defer t
  :config
  ;; TUI programs this repository uses, beyond eshell's own list.
  (dolist (cmd '("btop" "k9s" "lazydocker" "claude"))
    (add-to-list 'eshell-visual-commands cmd)))

;; eat runs a real bash, so the fzf keys and the .aliases functions work, which
;; eshell cannot offer. It is pure Elisp, from NonGNU ELPA: nothing native can
;; take the daemon down. .bashrc sources the shell integration for directory
;; tracking.
(use-package eat
  :hook (eshell-load . eat-eshell-visual-command-mode)
  :bind (("C-c t" . eat)
         :map project-prefix-map
         ("s" . eat-project))
  :custom
  ;; C-d closes the buffer, as it closes a tmux popup.
  (eat-kill-buffer-on-exit t)
  :config
  (add-to-list 'project-switch-commands '(eat-project "Shell") t))

;;;; Org

;; Notes live in $ORG_DIR, outside the Obsidian vault, which stays markdown
;; because Obsidian and the vault commands read it. Babel runs a block on
;; C-c C-c and asks once per block; a notebook shares one interpreter across
;; its blocks with `#+PROPERTY: header-args :session nb :results output'.
(use-package org
  :bind (("C-c a" . org-agenda)
         ("C-c c" . org-capture)
         ("C-c l" . org-store-link))
  :custom
  (org-directory (file-name-as-directory (or (getenv "ORG_DIR") "~/org")))
  (org-agenda-files (list org-directory))
  (org-default-notes-file (expand-file-name "inbox.org" org-directory))
  (org-startup-indented t)
  (org-hide-emphasis-markers t)
  (org-return-follows-link t)
  (org-src-window-setup 'current-window)
  (org-src-preserve-indentation t)
  (org-edit-src-content-indentation 0)
  (org-confirm-babel-evaluate t)
  ;; python3 on PATH. A notebook that needs packages sets, per file,
  ;; #+PROPERTY: header-args:python :python "uv run --project DIR python"
  (org-babel-python-command "python3")
  ;; ob-lisp defaults to SLIME; the REPL here is Sly.
  (org-babel-lisp-eval-fn #'sly-eval)
  :config
  (make-directory org-directory t)
  (require 'org-tempo)                  ; <s TAB expands to a src block
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((emacs-lisp . t) (shell . t) (python . t) (C . t) (lisp . t) (sqlite . t))))

;; A :session is an interpreter in a comint buffer, and Org never stops it.
;; Python sessions come from run-python (inferior-python-mode), shell sessions
;; from shell (shell-mode). Sly is left alone: it is your own REPL, and Babel
;; only borrows it.
(defun my/org-babel-kill-sessions ()
  "Kill every Babel session interpreter and its buffer."
  (interactive)
  (dolist (buf (buffer-list))
    (when (and (get-buffer-process buf)
               (with-current-buffer buf
                 (derived-mode-p 'inferior-python-mode 'shell-mode)))
      (let ((kill-buffer-query-functions nil))
        (kill-buffer buf)))))

(defun my/org-kill-sessions-when-last ()
  "Kill the Babel sessions when the last Org buffer closes."
  (when (and (derived-mode-p 'org-mode)
             (not (seq-some (lambda (b)
                              (and (not (eq b (current-buffer)))
                                   (eq (buffer-local-value 'major-mode b) 'org-mode)))
                            (buffer-list))))
    (my/org-babel-kill-sessions)))
(add-hook 'kill-buffer-hook #'my/org-kill-sessions-when-last)

;;;; Markdown

;; The Obsidian vault and every README. text-mode-hook gives the buffer its
;; proportional face and its wrapping.
(use-package markdown-mode
  :defer t)

;;;; KDB

;; q-mode edits .q files and runs a q shell in comint. Its flymake backend
;; evaluates the file in a local q, so a query file would flag every remote
;; table as unknown; flymake stays off in .q buffers, and nothing here turns
;; it on.
(use-package q-mode
  :defer t)

;; kdb.el, in lisp/, runs q buffers against a remote kdb server from
;; `kdb-targets': a local q holds the handle, results print at a wide console
;; and open in a grid, and completion offers the server's tables and columns.
;; The targets are site data: lisp/kdb-site.el sets them where it exists.
(use-package kdb
  :load-path "lisp"
  :hook (q-mode . kdb-mode)
  :bind-keymap ("C-c k" . kdb-map)
  :config (require 'kdb-site nil t))

;;;; Site

;; ~/.config/emacs/lisp/site.el is machine-local, outside the repository, like
;; kdb-site.el. It holds directory classes for shared repositories, whose
;; diffs must stay small, and adds no file to them. For example:
;;   (dir-locals-set-class-variables 'shared '((nil . ((my/format-on-save . nil)))))
;;   (dir-locals-set-directory-class "~/work/shared-repo/" 'shared)
(load (locate-user-emacs-file "lisp/site.el") 'noerror 'nomessage)

;;;; Server

(require 'server)
(unless (or noninteractive (server-running-p))
  (server-start))

;;; init.el ends here
