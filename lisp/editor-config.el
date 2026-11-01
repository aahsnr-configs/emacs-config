;;; editor-config.el --- Evil stack, general.el leader definers, core editing aids -*- lexical-binding: t; -*-

;;; Commentary:

;; The editing module.  Defines `ar/global-leader' and `ar/local-leader'
;; (used by every module loaded after this one) and configures the evil
;; stack -- the full Doom plugin suite plus this config's AST and
;; multi-cursor tools -- and the core editing aids.  Package installation
;; is handled exclusively by init.el's `ar/packages' manifest.

;;; Code:

(declare-function evil-multiedit-default-keybinds "evil-multiedit")
(declare-function ar/evil-avy-goto-char-2 "editor-config")
(declare-function ar/evil-avy-goto-line "editor-config")
(declare-function ar/evil-avy-goto-char-timer "editor-config")
(declare-function ar/ast-refactor-transient "editor-config")

;; Evil core engine.  Loaded eagerly: part of the startup eager-load budget.
(use-package evil
  :demand t
  :init
  (setq evil-want-integration t
        evil-want-keybinding nil
        evil-want-minibuffer nil
        evil-mode-line-format nil
        evil-kbd-macro-suppress-motion-error t
        evil-symbol-word-search t
        evil-undo-system 'undo-fu
        evil-kill-on-visual-paste nil)
  (setq evil-want-C-g-bindings t
        evil-want-C-i-jump nil
        evil-want-C-u-scroll t
        evil-want-C-u-delete t
        evil-want-C-w-delete t
        evil-want-Y-yank-to-eol t
        evil-want-abbrev-expand-on-insert-exit nil
        evil-respect-visual-line-mode nil)
  (setq evil-normal-state-cursor '(box)
        evil-insert-state-cursor '(bar)
        evil-visual-state-cursor '(hollow)
        evil-replace-state-cursor '(underline))
  :custom
  (evil-ex-visual-char-range t)
  (evil-ex-search-vim-style-regexp t)
  (evil-split-window-below t)
  (evil-vsplit-window-right t)
  (evil-echo-state nil)
  (evil-move-cursor-back nil)
  (evil-want-fine-undo t)
  (evil-move-beyond-eol nil)
  (evil-search-wrap t)
  (select-enable-clipboard t)
  (evil-visual-update-x-selection-p nil)
  (evil-ex-search-case 'smart)
  (evil-ex-search-incremental t)
  (evil-ex-search-highlight-all t)
  :config
  (evil-mode 1)
  (evil-select-search-module 'evil-search-module 'evil-search)
  (setq-default evil-shift-width tab-width)
  ;; Ex and search history cycling via arrow keys and Emacs bindings.
  (dolist (keymap (list evil-ex-completion-map
                        evil-ex-search-keymap))
    (define-key keymap (kbd "<up>") #'previous-history-element)
    (define-key keymap (kbd "<down>") #'next-history-element)
    (define-key keymap (kbd "C-p") #'previous-history-element)
    (define-key keymap (kbd "C-n") #'next-history-element))
  (evil-set-initial-state 'messages-buffer-mode 'normal))

;; Evil Collection: standardized Vim bindings for non-text buffers.
;; Minibuffer integration stays off to protect Vertico.
(use-package evil-collection
  :after evil
  :init
  (setq evil-collection-want-unimpaired-p t)
  :config
  (evil-collection-init))

;; evil-escape: a custom escape sequence (jk) for leaving insert state.
(use-package evil-escape
  :after evil
  :custom
  (evil-escape-key-sequence "jk")
  (evil-escape-delay 0.15)
  (evil-escape-excluded-states '(normal visual multiedit emacs motion))
  (evil-escape-excluded-major-modes '(magit-status-mode magit-diff-mode))
  :config
  (when (fboundp 'evil-escape-mode)
    (evil-escape-mode 1)))

;; Linear undo/redo backend consumed by `evil-undo-system'.
(use-package undo-fu
  :defer t)

;; Persistent undo across sessions, plus vundo for visual tree navigation.
(use-package undo-fu-session
  :demand t
  :custom
  (undo-fu-session-directory (ar/var-file "undo-fu-session/"))
  (undo-fu-session-linear t)
  (undo-fu-session-file-limit 500)
  (undo-fu-session-incompatible-files
   '("/COMMIT_EDITMSG\\'" "/git-rebase-todo\\'"))
  (undo-fu-session-incompatible-major-modes
   '(magit-status-mode magit-log-mode magit-diff-mode magit-revision-mode
                       git-commit-mode dired-mode dirvish-mode treemacs-mode eshell-mode
                       term-mode ghostel-mode compilation-mode grep-mode occur-mode
                       org-agenda-mode help-mode helpful-mode Info-mode special-mode))
  :config
  ;; Conditional compression: prefer zstd, fallback to gzip.
  (setq undo-fu-session-compression
        (cond ((executable-find "zstd") 'zst)
              ((executable-find "gzip") 'gz)
              (t nil)))
  ;; Stable `secure-hash' primitive bypasses OS 255-char limits.
  (defun ar/undo-fu-session-hash-path (file ext)
    "Safely hash FILE to bypass OS 255-char limits, appending EXT."
    (let* ((base (file-name-nondirectory file))
           (hash (substring (secure-hash 'sha1 file) 0 16)))
      (expand-file-name (concat hash "-" base ext) undo-fu-session-directory)))
  (setq undo-fu-session-make-file-name-function #'ar/undo-fu-session-hash-path)
  (undo-fu-session-global-mode 1))

;; TODO: Is vundo need if undo-fu and undo-fu-session is setup
(use-package vundo
  :defer t
  :commands (vundo)
  :custom
  (vundo-glyph-alist vundo-unicode-symbols))

;; gc comment operator backed by evil-nerd-commenter (decision: replaces
;; evil-commentary; language-aware commenting).
(use-package evil-nerd-commenter
  :after evil
  :commands (evilnc-comment-operator evilnc-comment-or-uncomment-lines)
  :config
  (evilnc-default-hotkeys))

;; Argument text objects bound to `a'.
(use-package evil-args
  :after evil
  :config
  (define-key evil-inner-text-objects-map "a" 'evil-inner-arg)
  (define-key evil-outer-text-objects-map "a" 'evil-outer-arg))

;; Numeric increment/decrement, autoloaded on first use.
(use-package evil-numbers
  :defer t
  :commands (evil-numbers/inc-at-pt evil-numbers/dec-at-pt))

;; gx motion to swap two text regions (gX cancels).
(use-package evil-exchange
  :after evil
  :config
  (evil-exchange-install))

;; Indent-based text objects (ii/ai, iI/aI, iJ/aJ).
(use-package evil-indent-plus
  :after evil
  :demand t)

;; Visual pulse feedback on evil edit operations.
(use-package evil-goggles
  :after evil
  :custom
  (evil-goggles-duration 0.1)
  :custom-face
  (evil-goggles-default-face ((t (:inherit highlight))))
  :config
  (evil-goggles-mode 1))

;; gl / gL alignment operators.
(use-package evil-lion
  :after evil
  :config
  (evil-lion-mode 1))

;; Retro-active Vim-style wrapping (ys/cs/ds) plus evil-embrace's
;; regex-aware structural pairs for prose and LaTeX environments.
(use-package evil-surround
  :after evil
  :config
  (global-evil-surround-mode 1))

(use-package evil-embrace
  :after evil-surround
  :config
  (evil-embrace-enable-evil-surround-integration)
  (add-hook 'org-mode-hook #'embrace-org-mode-hook)
  (add-hook 'LaTeX-mode-hook #'embrace-LaTeX-mode-hook)
  (defun ar/embrace-markdown-setup ()
    "Inject markdown emphasis and code pairs into embrace."
    (embrace-add-pair ?* "*" "*")
    (embrace-add-pair ?_ "_" "_")
    (embrace-add-pair ?` "`" "`"))
  (add-hook 'markdown-mode-hook #'ar/embrace-markdown-setup)
  (add-hook 'gfm-mode-hook #'ar/embrace-markdown-setup))

;; Closest enclosing block text object (ib/ab).
(use-package evil-textobj-anyblock
  :after evil
  :demand t)

;; Visual preview of ex substitution commands (:%s) as typed.
(use-package evil-traces
  :after evil
  :config
  (when (fboundp 'evil-traces-mode)
    (evil-traces-mode 1)))

;; `*'/`#' from visual state search the selection (evil-visualstar).
(use-package evil-visualstar
  :after evil
  :commands (evil-visualstar/begin-search-forward
             evil-visualstar/begin-search-backward)
  :config
  (define-key evil-visual-state-map "*"
              #'evil-visualstar/begin-search-forward)
  (define-key evil-visual-state-map "#"
              #'evil-visualstar/begin-search-backward))

;; XML/HTML attribute text object (ix/ax).
(use-package exato
  :after evil
  :demand t)

;; The `god' operator diffs two evil selections, `goD' cancels.  The
;; package ships no per-buffer mode: installing it binds the operator
;; keys once, triggered by the first git-tracked programming buffer.
(defun ar/evil-quick-diff-install-maybe ()
  "Install `evil-quick-diff' operator keys once a git buffer is opened."
  (when (and buffer-file-name
             (not (file-remote-p buffer-file-name))
             (eq (vc-backend buffer-file-name) 'Git))
    (evil-quick-diff-install)
    (remove-hook 'prog-mode-hook #'ar/evil-quick-diff-install-maybe)))

(use-package evil-quick-diff
  :after evil
  :commands (evil-quick-diff-install evil-quick-diff evil-quick-diff-cancel)
  :hook (prog-mode . ar/evil-quick-diff-install-maybe))

;; general.el defines the leader machinery shared by every later module.
(use-package general
  :demand t
  :after evil
  :config
  ;; Global leader prefix: SPC (also C-SPC), across evil states.
  ;; Local leader prefix: SPC m (also C-SPC m).  (with-no-warnings: the
  ;; definer macro generates docstrings the compiler nitpicks.)
  (with-no-warnings
    (general-create-definer ar/global-leader
      :states '(normal insert visual emacs)
      :prefix "SPC"
      :global-prefix "C-SPC")

    (general-create-definer ar/local-leader
      :states '(normal insert visual emacs)
      :prefix "SPC m"
      :global-prefix "C-SPC m")))

;; Top-level leader entries.
(ar/global-leader
  "SPC" '(execute-extended-command :wk "M-x")
  ":"   '(eval-expression :wk "Eval")
  "u"   '(universal-argument :wk "Universal arg")
  "!"   '(shell-command :wk "Shell cmd")
  "X"   '(org-capture :wk "Org capture"))

;; Intercepts evil's o/O operators to continue comment lines natively.
(defcustom ar/evil-want-o/O-to-continue-comments t
  "If non-nil, o/O keys will continue comment lines."
  :type 'boolean
  :group 'ar)

(defun ar/evil-open-below-smart ()
  "Open line below, continuing comments if applicable."
  (interactive)
  (if (and ar/evil-want-o/O-to-continue-comments
           comment-start-skip
           (save-excursion
             (beginning-of-line)
             (re-search-forward comment-start-skip (line-end-position) t)))
      (progn
        (end-of-line)
        (comment-indent-new-line)
        (evil-insert-state))
    (evil-open-below (prefix-numeric-value current-prefix-arg))))

(defun ar/evil-open-above-smart ()
  "Open line above, continuing comments if applicable."
  (interactive)
  (if (and ar/evil-want-o/O-to-continue-comments
           comment-start-skip
           (save-excursion
             (beginning-of-line)
             (re-search-forward comment-start-skip (line-end-position) t)))
      (progn
        (beginning-of-line)
        (re-search-forward comment-start-skip (line-end-position) t)
        (comment-indent-new-line)
        (forward-line -1)
        (indent-according-to-mode)
        (re-search-forward comment-start-skip (line-end-position) t)
        (evil-insert-state))
    (evil-open-above (prefix-numeric-value current-prefix-arg))))

(general-define-key
 :states 'normal
 "o" #'ar/evil-open-below-smart
 "O" #'ar/evil-open-above-smart)

;; Auto-save on idle and at natural navigation boundaries.
(use-package super-save
  :hook (after-init . super-save-mode)
  :custom
  (super-save-auto-save-when-idle t)
  (super-save-idle-duration 10)
  (super-save-remote-files nil)
  (super-save-triggers
   '(other-window
     windmove-up
     windmove-down
     windmove-left
     windmove-right
     ace-window)))

;; Native delete-pair tuning plus an O(1) DWIM wrapper, confined to
;; programming modes.
(setq delete-pair-blink-delay 0.1
      delete-pair-push-mark t)

(defun ar/delete-pair-dwim ()
  "Intelligently delete the pair surrounding or preceding the cursor.
Strictly confined to `prog-mode' to prevent structural destruction in
prose."
  (interactive)
  (unless (derived-mode-p 'prog-mode)
    (user-error "Delete Pair DWIM restricted to prog-mode; use `ds' in prose"))
  (let ((prev (char-before))
        (next (char-after))
        (ppss (syntax-ppss)))
    (cond
     ((and prev (memq (char-syntax prev) '(?\) ?\" ?\|)))
      (delete-pair -1))
     ((and next (memq (char-syntax next) '(?\( ?\" ?\|)))
      (delete-pair 1))
     ((nth 3 ppss)
      (let ((start (nth 8 ppss)))
        (goto-char start)
        (unless (memq (char-after) '(?\" ?\|))
          (forward-char 1))
        (delete-pair 1)))
     (t
      (condition-case nil
          (progn
            (backward-up-list)
            (delete-pair 1))
        (scan-error (user-error "Not inside a deletable pair")))))))

;; AST text objects for evil's operator-pending maps plus Unimpaired-style
;; goto motions.
(use-package evil-textobj-tree-sitter
  :demand t
  :after evil
  :config
  (with-no-warnings
    (define-key evil-inner-text-objects-map "f" (evil-textobj-tree-sitter-get-textobj "function.inner"))
    (define-key evil-outer-text-objects-map "f" (evil-textobj-tree-sitter-get-textobj "function.outer"))
    (define-key evil-inner-text-objects-map "F" (evil-textobj-tree-sitter-get-textobj "call.inner"))
    (define-key evil-outer-text-objects-map "F" (evil-textobj-tree-sitter-get-textobj "call.outer"))
    (define-key evil-inner-text-objects-map "C" (evil-textobj-tree-sitter-get-textobj "class.inner"))
    (define-key evil-outer-text-objects-map "C" (evil-textobj-tree-sitter-get-textobj "class.outer"))
    (define-key evil-outer-text-objects-map "c" (evil-textobj-tree-sitter-get-textobj "comment.outer"))
    (define-key evil-inner-text-objects-map "v" (evil-textobj-tree-sitter-get-textobj "conditional.inner"))
    (define-key evil-outer-text-objects-map "v" (evil-textobj-tree-sitter-get-textobj "conditional.outer"))
    (define-key evil-inner-text-objects-map "l" (evil-textobj-tree-sitter-get-textobj "loop.inner"))
    (define-key evil-outer-text-objects-map "l" (evil-textobj-tree-sitter-get-textobj "loop.outer"))
    (define-key evil-inner-text-objects-map "a" (evil-textobj-tree-sitter-get-textobj ("parameter.inner" "call.inner")))
    (define-key evil-outer-text-objects-map "a" (evil-textobj-tree-sitter-get-textobj ("parameter.outer" "call.outer"))))

  ;; Dynamically registers named interactive commands for bracket goto.
  (defun ar/ts-register-goto (key node &optional previous)
    "Bind KEY to a goto command for tree-sitter NODE; PREVIOUS inverts it."
    (let* ((suffix (if previous "prev" "next"))
           (cmd-name (intern (format "ar/ts-goto-%s-%s"
                                     (string-replace "." "-" node)
                                     suffix)))
           (doc (format "Jump to %s %s node." (if previous "previous" "next") node)))
      (defalias cmd-name
        `(lambda ()
           (interactive)
           (evil-textobj-tree-sitter-goto-textobj ,node ,previous))
        doc)
      (general-define-key
       :states '(normal visual motion)
       key cmd-name)))

  (ar/ts-register-goto "]f" "function.outer")
  (ar/ts-register-goto "[f" "function.outer" t)
  (ar/ts-register-goto "]F" "call.outer")
  (ar/ts-register-goto "[F" "call.outer" t)
  (ar/ts-register-goto "]C" "class.outer")
  (ar/ts-register-goto "[C" "class.outer" t)
  (ar/ts-register-goto "]c" "comment.outer")
  (ar/ts-register-goto "[c" "comment.outer" t)
  (ar/ts-register-goto "]v" "conditional.outer")
  (ar/ts-register-goto "[v" "conditional.outer" t)
  (ar/ts-register-goto "]l" "loop.outer")
  (ar/ts-register-goto "[l" "loop.outer" t)
  (ar/ts-register-goto "]a" "parameter.outer")
  (ar/ts-register-goto "[a" "parameter.outer" t)

  (with-eval-after-load 'which-key
    (add-to-list 'which-key-replacement-alist
                 '(("" . "\\`+?evil-textobj-tree-sitter-function--\\(.*\\)\\(?:\\.inner\\|\\.outer\\)") . (nil . "\\1")))))

;; AST-aware structural manipulation (drag/swap/extract/raise) built on
;; the Emacs 30 `treesit-thing' API.
(defun ar/evil-ts-obj-maybe-enable ()
  "Enable `evil-ts-obj-mode' in prog modes, except where it fights
the plain-list/Makefile machinery."
  (unless (derived-mode-p
           'emacs-lisp-mode 'lisp-mode
           'makefile-mode 'snippet-mode 'ron-mode)
    (evil-ts-obj-mode)))

(use-package evil-ts-obj
  :defer t
  :after evil
  :hook ((prog-mode . ar/evil-ts-obj-maybe-enable)
         ((LaTeX-mode markdown-mode markdown-ts-mode yaml-mode yaml-ts-mode) . evil-ts-obj-mode)))

(ar/define-large-file-guard evil-ts-obj-mode)

;; The AST refactor transient: defined as soon as transient loads so the
;; "c s" leader entry resolves before the first tree-sitter buffer opens.
(with-eval-after-load 'transient
  (with-no-warnings
    (defun ar/ast-refactor-title ()
      "Return the titled heading for the AST refactor transient."
      (concat
       (if (fboundp 'nerd-icons-codicon)
           (nerd-icons-codicon "nf-cod-symbol_structure" :face 'transient-heading :v-adjust 0.02)
         "")
       (propertize " AST Refactor" 'face 'transient-heading)))

    (transient-define-prefix ar/ast-refactor-transient ()
      "AST Structural Refactoring"
      [:description ar/ast-refactor-title
                    ["Drag & Swap"
                     ("j" "Drag Down" evil-ts-obj-drag-down :transient t)
                     ("k" "Drag Up" evil-ts-obj-drag-up :transient t)
                     ("J" "Swap Down" evil-ts-obj-swap-dwim-down :transient t)
                     ("K" "Swap Up" evil-ts-obj-swap-dwim-up :transient t)]
                    ["Extract & Inject"
                     ("l" "Extract Out" evil-ts-obj-extract-down-dwim :transient t)
                     ("h" "Extract In" evil-ts-obj-extract-up-dwim :transient t)
                     ("s" "Inject Down" evil-ts-obj-inject-down-dwim :transient t)
                     ("S" "Inject Up" evil-ts-obj-inject-up-dwim :transient t)]
                    ["Mutate"
                     ("r" "Raise" evil-ts-obj-raise-dwim :transient t)
                     ("c" "Clone After" evil-ts-obj-clone-after-dwim :transient t)
                     ("C" "Clone Before" evil-ts-obj-clone-before-dwim :transient t)
                     (">" "Slurp" evil-ts-obj-slurp :transient t)
                     ("<" "Barf" evil-ts-obj-barf :transient t)
                     ("<escape>" "" transient-quit-one :format " ")]])

    (ar/global-leader
      "c s" '(ar/ast-refactor-transient :wk "Structure refactor"))))

;; Exposes the Emacs 30 `treesit-thing' API as bracket motions (no-op
;; outside ts modes).
(general-define-key
 :states '(normal visual motion)
 "]s" (lambda () (interactive) (ignore-errors (treesit-thing-next (point) 'sentence)))
 "[s" (lambda () (interactive) (ignore-errors (treesit-thing-prev (point) 'sentence)))
 "]x" (lambda () (interactive) (ignore-errors (treesit-thing-next (point) 'sexp)))
 "[x" (lambda () (interactive) (ignore-errors (treesit-thing-prev (point) 'sexp))))

;; O(1) AST-aware visual selection expansion via the native treesit
;; engine, integrated with repeat-mode.
(use-package expreg
  :if (treesit-available-p)
  :defer t
  :commands (expreg-expand expreg-contract)
  :config
  (setq expreg-restore-point-on-quit t)
  (defvar-keymap expreg-repeat-map
    :doc "Keymap for repeating expreg commands."
    "+" #'expreg-expand
    "=" #'expreg-expand
    "-" #'expreg-contract
    "_" #'expreg-contract)
  (put 'expreg-expand 'repeat-map 'expreg-repeat-map)
  (put 'expreg-contract 'repeat-map 'expreg-repeat-map))

(general-define-key :states 'visual "v" #'expreg-expand)

(general-define-key
 :states '(normal visual motion)
 "M-=" #'expreg-expand
 "C-M-+" #'expreg-expand
 "C-M--" #'expreg-contract)

;; Trims trailing whitespace only on edited lines, keeping VCS diffs clean.
(use-package ws-butler
  :defer t
  :hook (prog-mode . ws-butler-mode))

;; O(1) radix-tree jumping engine: home-row keys, proximity sorting, and
;; the isearch M-j touch.
(use-package avy
  :defer t
  :commands (avy-goto-char-2
             avy-goto-line
             avy-goto-word-1
             avy-goto-symbol-1
             avy-goto-char-timer
             avy-isearch
             avy-move-line
             avy-copy-line
             avy-kill-region
             avy-transpose-lines-in-region
             avy-move-region
             avy-copy-region
             avy-kill-ring-save-region
             avy-pop-mark)
  :bind (:map isearch-mode-map
              ("M-j" . avy-isearch))
  :custom
  (avy-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l))
  (avy-style 'at-full)
  (avy-background t)
  (avy-all-windows nil)
  (avy-all-windows-alt t)
  (avy-single-candidate-jump nil)
  (avy-orders-alist '((avy-goto-char . avy-order-closest)
                      (avy-goto-word-0 . avy-order-closest)
                      (avy-goto-word-1 . avy-order-closest)))
  (avy-timeout-seconds 0.3)
  :custom-face
  (avy-lead-face-0 ((t (:background "#f7768e" :foreground "#1a1b26" :weight bold))))
  (avy-lead-face-1 ((t (:background "#e0af68" :foreground "#1a1b26" :weight bold))))
  (avy-lead-face-2 ((t (:background "#9ece6a" :foreground "#1a1b26" :weight bold))))
  (avy-lead-face ((t (:background "#7dcfff" :foreground "#1a1b26" :weight bold)))))

;; Wraps avy into evil's operator-pending grammar under a unified gs
;; prefix.
(use-package evil-easymotion
  :after (evil avy)
  :config
  (evil-define-motion ar/evil-avy-goto-char-2 ()
    "Jump to 2-char target."
    :type exclusive :jump t
    (avy-goto-char-2))
  (evil-define-motion ar/evil-avy-goto-line ()
    "Jump to visible line."
    :type line :jump t
    (avy-goto-line))
  (evil-define-motion ar/evil-avy-goto-char-timer ()
    "Jump to string target via timer."
    :type exclusive :jump t
    (avy-goto-char-timer))
  (evilem-default-keybindings "gs")
  (define-key evilem-map "s" #'ar/evil-avy-goto-char-2)
  (define-key evilem-map "l" #'ar/evil-avy-goto-line)
  (define-key evilem-map "SPC" #'ar/evil-avy-goto-char-timer))

;; Incremental, regex-aware s/S jumps.
(use-package evil-snipe
  :after evil
  :custom
  (evil-snipe-enable-highlight t)
  (evil-snipe-enable-incremental-highlight t)
  (evil-snipe-scope 'whole-visible)
  (evil-snipe-smart-case t)
  (evil-snipe-show-prompt nil)
  (evil-snipe-auto-scroll t)
  (evil-snipe-spillover-scope 'whole-buffer)
  (evil-snipe-tab-increment t)
  :custom-face
  (evil-snipe-first-match-face ((t (:foreground "#7dcfff" :underline t))))
  (evil-snipe-matches-face ((t (:foreground "#7dcfff" :underline t))))
  :config
  (dolist (mode '(dirvish-directory-view-mode
                  dirvish-mode
                  git-timemachine-mode
                  eshell-mode
                  ghostel-mode
                  term-mode
                  compilation-mode
                  grep-mode
                  occur-mode
                  flymake-diagnostics-buffer-mode
                  xref--xref-buffer-mode
                  embark-collect-mode
                  help-mode
                  helpful-mode
                  Info-mode
                  woman-mode
                  eww-mode
                  Custom-mode
                  ediff-mode
                  profiler-report-mode
                  messages-buffer-mode
                  backtrace-mode))
    (add-to-list 'evil-snipe-disabled-modes mode))
  (push '(?\[ "[[{(<]") evil-snipe-aliases)
  (push '(?\] "[]})>]") evil-snipe-aliases)
  (push '(?\" "[\"'`´]") evil-snipe-aliases)
  (evil-snipe-mode 1)
  (evil-snipe-override-mode 1)
  (evil-define-key 'visual evil-snipe-local-mode-map "z" #'evil-snipe-s)
  (evil-define-key 'visual evil-snipe-local-mode-map "Z" #'evil-snipe-S)
  (with-eval-after-load 'evil-easymotion
    (define-key evil-snipe-parent-transient-map "g" evilem-map)))

;; Avy-backed navigation to and mutation of visible URLs, file paths, and
;; buttons, with an embark fallback.
(use-package link-hint
  :commands (link-hint-open-link
             link-hint-copy-link
             link-hint-open-multiple-links
             link-hint-copy-all-links
             link-hint-open-link-at-point
             link-hint-copy-link-at-point)
  :custom
  (link-hint-action-fallback-commands
   (list :open (lambda ()
                 (condition-case _
                     (progn (embark-dwim) t)
                   (error nil))))))

;; Match index/total in the modeline during searches.
(use-package anzu
  :demand t
  :bind (([remap query-replace] . anzu-query-replace)
         ([remap query-replace-regexp] . anzu-query-replace-regexp)
         :map isearch-mode-map
         ([remap isearch-query-replace] . anzu-isearch-query-replace)
         ([remap isearch-query-replace-regexp] . anzu-isearch-query-replace-regexp))
  :custom
  (anzu-mode-lighter "")
  (anzu-deactivate-region t)
  (anzu-search-threshold 1000)
  (anzu-replace-threshold 50)
  (anzu-replace-to-string-separator " → ")
  (anzu-cons-mode-line-p nil)
  :config
  (global-anzu-mode 1))

(use-package evil-anzu
  :after (evil anzu))

;; Occurrence editing engine backing evil-multiedit.
(use-package iedit
  :commands (iedit-mode
             iedit-rectangle-mode)
  :custom
  (iedit-toggle-key-default nil)
  (iedit-auto-narrow nil)
  (iedit-occurrence-context-lines 1))

;; Multi-cursor editing over iedit.
(use-package evil-multiedit
  :after evil
  :defer t
  :commands (evil-multiedit-match-symbol-and-next
             evil-multiedit-match-symbol-and-prev
             evil-multiedit-match-all
             evil-multiedit-abort
             evil-multiedit-toggle-or-restrict-region)
  :custom-face
  ;; evil-multiedit defines no faces of its own; the match highlight comes
  ;; from iedit's occurrence face.
  (iedit-occurrence ((t (:background "#bb9af7" :foreground "#1a1b26"))))
  :config
  (evil-multiedit-default-keybinds))

(general-define-key
 :states '(normal visual)
 "M-d" #'evil-multiedit-match-symbol-and-next
 "M-D" #'evil-multiedit-match-all)

(general-define-key
 :states 'visual
 "C-S-<down>" #'evil-multiedit-match-symbol-and-next
 "C-S-<up>"   #'evil-multiedit-match-symbol-and-prev)

(ar/global-leader
  "c v"   '(:ignore t :wk "multi-cursor")
  "c v v" '(evil-multiedit-match-symbol-and-next :wk "Make cursor here")
  "c v a" '(evil-multiedit-match-all :wk "Make all cursors")
  "c v q" '(evil-multiedit-abort :wk "Undo all cursors")
  "c v r" '(evil-multiedit-toggle-or-restrict-region :wk "Restrict region")
  "c v I" '(evil-multiedit-match-symbol-and-prev :wk "Cursors in selection (beg)")
  "c v A" '(evil-multiedit-match-symbol-and-next :wk "Cursors in selection (end)"))

;; Enchant-based JIT spell checking (kept vanilla extra, diverges from
;; init.md's disabled :checkers spell).
(use-package jinx
  :defer t
  :init
  (defvar ar/jinx-disabled-modes
    '(prog-mode
      conf-mode
      emacs-lisp-mode
      dired-mode
      ibuffer-mode
      treemacs-mode
      magit-status-mode
      magit-log-mode
      magit-diff-mode
      magit-branch-mode
      org-agenda-mode
      org-src-mode
      which-key-mode
      help-mode
      Info-mode
      embark-collect-mode
      ghostel-mode
      term-mode)
    "Modes in which Jinx should not activate.")
  (defvar ar/jinx-personal-words
    "emacs elisp use-package org-mode prog-mode conf-mode text-mode
lsp flymake minibuffer config corfu vertico orderless consult embark
denote treemacs dirvish magit evil avy anzu jinx persp
tokyo night jetbrainsmono nerd font pgtk wayland ui
tramp ssh json yaml toml lsp dap ast"
    "Personal vocabulary injected as `jinx-local-words' in prose buffers.")
  ;; Activation probe: jinx-mode loads its native module on first use; in
  ;; environments where that fails (e.g. hidden Org buffers created during
  ;; lsp-mode's org-element detection) the failure must not propagate.
  (defvar ar/jinx-module-ok 'unknown
    "Whether jinx's native module loaded successfully.")
  (defun ar/jinx-mode-maybe ()
    "Enable `jinx-mode' once its native module is known to work."
    (when (eq ar/jinx-module-ok 'unknown)
      (setq ar/jinx-module-ok
            (condition-case nil
                (progn (jinx-mode 1) (jinx-mode -1) t)
              (error nil))))
    (when (eq ar/jinx-module-ok t)
      (jinx-mode 1)))
  (add-hook 'text-mode-hook #'ar/jinx-mode-maybe)
  (defun ar/jinx-personal-words-h ()
    "Inject the personal vocabulary into prose buffers."
    (setq-local jinx-local-words ar/jinx-personal-words))
  (dolist (mode '(org-mode
                  LaTeX-mode
                  markdown-mode
                  gfm-mode
                  text-mode))
    (add-hook (intern (format "%s-hook" mode)) #'ar/jinx-personal-words-h))
  :custom
  (jinx-languages "en")
  :config
  (setq jinx-exclude-regexps
        `((emacs-lisp-mode "Package-Requires:.*$")
          (org-mode ,(rx "\\" (+ alpha)))
          (LaTeX-mode ,(rx "\\" (+ alpha)))
          (t "[A-Z]+\\>"
             "-+\\>"
             "\\w*?[0-9]\\w*\\>"
             "[a-z]+://\\S-+"
             "<?[-+_.~a-zA-Z][-+_.~:a-zA-Z0-9]*@[-.a-zA-Z0-9]+>?"
             "\\(?:Local Variables\\|End\\):\\s-*$"
             "jinx-\\(?:languages\\|local-words\\):\\s-+.*$"
             "[/~][a-zA-Z0-9._/-]+")))
  (setf (alist-get 'org-mode jinx-exclude-faces)
        (append (alist-get 'org-mode jinx-exclude-faces)
                '(org-level-1 org-level-2 org-level-3 org-level-4
                              org-level-5 org-level-6 org-level-7 org-level-8
                              org-document-title org-document-info org-priority)))
  (define-advice jinx--on (:before-while () guard-disabled-modes)
    (not (apply #'derived-mode-p ar/jinx-disabled-modes))))

(ar/define-large-file-guard jinx-mode)

;; Rich help buffers with source, callers, and keybindings, remapped over
;; the describe-* family.
(use-package helpful
  :commands (helpful-callable
             helpful-variable
             helpful-key
             helpful-command
             helpful-at-point
             helpful-function
             helpful-symbol)
  :bind
  ([remap describe-command] . helpful-command)
  ([remap describe-function] . helpful-callable)
  ([remap describe-key] . helpful-key)
  ([remap describe-symbol] . helpful-symbol)
  ([remap describe-variable] . helpful-variable)
  :custom
  (helpful-max-buffers 7)
  (apropos-do-all t))

;; Snippet engine: personal collection first (shadows doom-snippets on
;; name clash), community collection, hot-reload on save.
(defvar ar/snippets-directory (expand-file-name "snippets" ar/config-dir)
  "Directory for personal yasnippet snippets.")

(unless (file-directory-p ar/snippets-directory)
  (make-directory ar/snippets-directory t))

(use-package yasnippet
  :defer t
  :hook ((prog-mode text-mode conf-mode comint-mode) . yas-minor-mode)
  :custom
  (yas-also-auto-indent-first-line t)
  (yas-also-indent-empty-lines t)
  (yas-snippet-revival nil)
  (yas-wrap-around-region nil)
  :config
  (add-to-list 'yas-snippet-dirs ar/snippets-directory)
  (defun ar/yas-reload-snippets-on-save ()
    "Reload all snippets if a snippet file is being saved."
    (when-let* ((file (buffer-file-name)))
      (when (string-prefix-p ar/snippets-directory file)
        (yas-reload-all)
        (message "Yasnippet collection reloaded."))))
  (add-hook 'after-save-hook #'ar/yas-reload-snippets-on-save))

;; Doom's curated snippet collection registers itself against yasnippet;
;; load defensively in case the package ships no feature symbol.
(with-eval-after-load 'yasnippet
  (when (locate-library "doom-snippets")
    (require 'doom-snippets nil t))
  (yas-reload-all))

;; Record ad-hoc templates from typed examples.
(use-package auto-yasnippet
  :defer t
  :commands (aya-create aya-expand aya-open-line))

;; Reopen the current file via TRAMP sudo.
(use-package sudo-edit
  :defer t
  :commands (sudo-edit))

(ar/global-leader
  "f E" '(sudo-edit :wk "Sudo edit"))

;; Word wrap (:editor word-wrap): adaptive prefix indentation + visual columns.
(use-package adaptive-wrap
  :defer t
  :hook (visual-line-mode . adaptive-wrap-prefix-mode))

(use-package visual-fill-column
  :defer t
  :hook (visual-line-mode . visual-fill-column-mode)
  :custom
  (visual-fill-column-width 100)
  (visual-fill-column-center-text t))

(provide 'editor-config)
;;; editor-config.el ends here
