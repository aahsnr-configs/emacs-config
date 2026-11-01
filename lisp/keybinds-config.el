;;; keybinds-config.el --- Leader trees, transient menus, windows, misc bindings -*- lexical-binding: t; -*-

;;; Commentary:

;; The keybinding module: the unified escape/minibuffer plumbing, the
;; global and local leader trees, transient menus, window management, and
;; which-key.  Popup windows are managed by the Doom popup port in
;; ui-config.

;;; Code:

;; Unified escape and minibuffer plumbing.  `ar/escape-key' is defined in
;; the core module and bound here; it delegates to `abort-recursive-edit'
;; when the minibuffer is active.
(defvar ar/minibuffer-escape-maps
  '(minibuffer-local-map
    minibuffer-local-ns-map
    minibuffer-local-completion-map
    minibuffer-local-must-match-map
    minibuffer-local-isearch-map
    read-expression-map
    evil-ex-completion-map
    evil-ex-search-keymap)
  "Minibuffer and Ex keymaps receiving the escape and history bindings.")

(dolist (map-sym ar/minibuffer-escape-maps)
  (when (boundp map-sym)
    (define-key (symbol-value map-sym) (kbd "<escape>") #'ar/escape-key)
    (define-key (symbol-value map-sym) (kbd "C-s") #'consult-history)))

(general-define-key
 :states '(normal visual motion)
 "<escape>" #'ar/escape-key)

;; The generic file (SPC f), search (SPC s), quit/session (SPC q) and
;; open/frame (SPC o) leader trees.  Entries that belong to a module's own
;; commands stay there.
(defvar ar/config-dir)

(defun ar/open-config-dir ()
  "Open the configuration root directory."
  (interactive)
  (find-file ar/config-dir))

(defun ar/open-init-file ()
  "Open user init.el."
  (interactive)
  (find-file user-init-file))

(ar/global-leader
  ;; File operations (SPC f).
  "f"     '(:ignore t :wk "file")
  "f f"   '(find-file :wk "Find file")
  "f r"   '(consult-recent-file :wk "Recent files")
  "f s"   '(save-buffer :wk "Save file")
  "f S"   '(write-file :wk "Save as")
  "f l"   '(reload-init-file :wk "Reload config")
  "f e"   '(:ignore t :wk "emacs")
  "f e d" '(ar/open-config-dir :wk "Open config root")
  "f e i" '(ar/open-init-file :wk "Open init.el")
  "f P"   '(ar/dashboard-open-config :wk "Open config root")
  ;; Help (SPC h).
  "h"     '(:ignore t :wk "help")
  "h d h" '(info-emacs-manual :wk "Emacs manual")
  "f d"   '(consult-dir :wk "Change directory")
  "f j"   '(consult-dir-jump-file :wk "Jump to file in dir")
  ;; Search operations (SPC s).
  "s"     '(:ignore t :wk "search")
  "s c"   '(evil-ex-nohighlight :wk "Clear highlights")
  "s s"   '(consult-line :wk "Search buffer")
  "s S"   '(consult-line-multi :wk "Search buffers")
  "s p"   '(consult-ripgrep :wk "Search project")
  "s d"   '(consult-dir :wk "Search directory")
  "s i"   '(consult-imenu :wk "Imenu")
  "s I"   '(consult-imenu-multi :wk "Imenu multi")
  "s o"   '(consult-outline :wk "Outline")
  "s b"   '(consult-line :wk "Search buffer")
  "s m"   '(consult-mark :wk "Mark ring")
  "s e"   '(consult-isearch-history :wk "Search history")
  "s r"   '(vertico-repeat :wk "Repeat last search")
  ;; Session management (SPC q).
  "q"     '(:ignore t :wk "quit/session")
  "q q"   '(save-buffers-kill-terminal :wk "Quit Emacs")
  "q Q"   '(kill-emacs :wk "Quit (no save)")
  "q f"   '(delete-frame :wk "Delete frame")
  "q s"   '(persp-save-to-file-by-names :wk "Save session")
  "q l"   '(persp-load-from-file-by-names :wk "Load session")
  "q L"   '(ar/dashboard-load-session :wk "Reload last session")
  "RET"   '(bookmark-jump :wk "Jump to bookmark")
  ;; Open / applications (SPC o) additions.
  "o b"   '(browse-url-of-file :wk "Browser")
  "o f"   '(make-frame :wk "New frame")
  "o F"   '(select-frame-by-name :wk "Select frame")
  "o i"   '(ielm :wk "REPL (Elisp)"))

;; AI assistants (SPC o a).  The clients are configured by llm-config,
;; loaded before this module.  Keep all LLM keybindings here so they do not
;; conflict with the existing global/local leader trees.
(ar/global-leader
  "o a"   '(:ignore t :wk "AI assistants")
  "o a c" '(codex-ide-menu :wk "Codex IDE menu")
  "o a C" '(codex-ide :wk "Start Codex session")
  "o a o" '(agent-shell :wk "OpenCode session")
  "o a O" '(ar/llm-opencode-new :wk "New OpenCode session")
  "o a g" '(gptel :wk "ChatGPT chat")
  "o a s" '(gptel-send :wk "Send prompt/selection")
  "o a m" '(ar/llm-gptel-menu :wk "ChatGPT options")
  "o a r" '(ar/llm-gptel-rewrite :wk "Rewrite with ChatGPT")
  "o a a" '(ar/llm-gptel-add :wk "Add ChatGPT context")
  "o a l" '(ar/llm-gptel-login :wk "ChatGPT login")
  "o a ?" '(ar/llm-check-prerequisites :wk "Check LLM tools"))

;; Global zoom bindings (commands defined in the ui module).
(general-define-key
 "C-=" #'ar/global-zoom-in
 "C--" #'ar/global-zoom-out
 "C-0" #'ar/global-zoom-reset
 "C-<wheel-up>" #'ar/global-zoom-in
 "C-<wheel-down>" #'ar/global-zoom-out)

;; Transient base: rectangular grid alignment for the custom transient
;; menus.
(use-package transient
  :demand t
  :custom
  (transient-align-variable-pitch t))

;; Keystroke discovery in the echo area.
(use-package which-key
  :custom
  (which-key-idle-delay 1.0)
  (which-key-idle-secondary-delay 0.05)
  (which-key-popup-type 'minibuffer)
  (which-key-separator " → ")
  (which-key-sort-order 'which-key-key-order-alpha)
  (which-key-sort-uppercase-first nil)
  (which-key-add-column-padding 1)
  (which-key-max-description-length 30)
  (which-key-allow-multiple-replacements t)
  (which-key-show-operator-state-maps t)
  :config
  (which-key-mode 1))

;; Cross-window jumps and dispatch via ace-window's avy engine.
(use-package ace-window
  :commands (ace-window
             ace-swap-window
             ace-delete-window
             ace-delete-other-windows)
  :custom
  (aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l))
  (aw-scope 'frame)
  (aw-background nil)
  (aw-dispatch-always t)
  (aw-ignored-buffers '("*Calc Trail*" " *LV*"
                        treemacs-mode
                        dirvish-mode
                        dirvish-directory-view-mode
                        "*which-key*"))
  :custom-face
  (aw-leading-char-face ((t (:foreground "#1a1b26" :background "#e0af68" :weight bold :height 2.5))))
  :config
  (ace-window-display-mode 1))

;; Layout history, wrap-around directional movement and the SPC w leader
;; tree.
(use-package winner
  :custom
  (winner-boring-buffers '("*Completions*"
                           "*Compile-Log*"
                           "*Apropos*"
                           "*Help*"
                           "*Buffer List*"
                           "*Ibuffer*"
                           "*Messages*"
                           "*Warnings*"))
  :config
  (winner-mode 1))

(setopt windmove-wrap-around t)

(ar/global-leader
  "w"           '(:ignore t :wk "window")
  ;; Ace window routing.
  "w w"         '(ace-window :wk "Ace window")
  "w d"         '(ace-delete-window :wk "Ace delete window")
  "w m"         '(ace-delete-other-windows :wk "Maximize")
  "w x"         '(ace-swap-window :wk "Ace swap window")
  ;; Native splitting.
  "w s"         '(split-window-below :wk "Split below")
  "w v"         '(split-window-right :wk "Split right")
  ;; Directional navigation.
  "w <left>"    '(evil-window-left :wk "Window left")
  "w <down>"    '(evil-window-down :wk "Window down")
  "w <up>"      '(evil-window-up :wk "Window up")
  "w <right>"   '(evil-window-right :wk "Window right")
  ;; Directional transposition.
  "w S-<left>"  '(evil-window-move-far-left :wk "Move far left")
  "w S-<down>"  '(evil-window-move-very-bottom :wk "Move bottom")
  "w S-<up>"    '(evil-window-move-very-top :wk "Move top")
  "w S-<right>" '(evil-window-move-far-right :wk "Move far right")
  ;; Utilities and layout history.
  "w ="         '(balance-windows :wk "Balance windows")
  "w u"         '(winner-undo :wk "Winner undo")
  "w r"         '(winner-redo :wk "Winner redo")
  "w t"         '(ar/window-toggle-split-direction :wk "Toggle split"))

(provide 'keybinds-config)
;;; keybinds-config.el ends here
