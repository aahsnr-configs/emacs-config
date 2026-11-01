;;; init.el --- Package bootstrap and module loader for vanilla Emacs 31.1 -*- lexical-binding: t; -*-

;;; Commentary:

;; This file is the single source of truth for package management and
;; module wiring.  Packages are owned by straight.el: a bootstrap fetches
;; straight itself, the complete manifest (`ar/packages') is cloned and
;; built in one pass under a loud failure contract, all state files are
;; routed into etc/ and var/ natively (early-init.el, no no-littering),
;; and the modules under lisp/ are loaded in a load-bearing order.
;; early-init.el runs before this file and owns everything that must
;; happen before the first frame.

;;; Code:

;; straight.el bootstrap.  straight owns every external package: it clones
;; recipe repositories and builds from git, sidestepping TLS-restricted
;; ELPA hosts -- everything arrives from GitHub mirrors instead.
;; `straight-check-for-modifications' must be set before straight loads.
(defvar straight-check-for-modifications) ;; declared so the setq compiles clean
(setq straight-check-for-modifications '(check-on-save))

(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name
        "straight/repos/straight.el/bootstrap.el"
        (or (bound-and-true-p straight-base-dir)
            user-emacs-directory)))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; Resolve dependencies against the Emacs 31.1 bundled libraries.  A plain
;; manifest pass would let straight rebuild bundled libraries whenever any
;; package's PACKAGE-REQUIRES mentions them; registering them as
;; :type built-in keeps the Emacs build's own versions on `load-path'.
(dolist (built-in '(compat eldoc external-completion flymake jsonrpc
                    org project seq transient xref))
  (straight-use-package (list built-in :type 'built-in)))

;; The external package manifest.  init.el is the only place that installs
;; anything: every package the later modules declare is listed here, as
;; either a plain package name (straight's default recipe repositories
;; resolve melpa and gnu-elpa-mirror recipes) or an explicit straight
;; recipe for git-only packages.  Grouped by the module that configures
;; each entry.

(defvar ar/packages
  '(;; core: framework parity (gcmh/nerd-icons/project/which-key are Doom
    ;; core-shipped; compat covers 31.1 APIs) + vanilla-kept basics
    gcmh compat nerd-icons posframe general projectile buffer-terminator

    ;; editor: evil stack -- Doom suite + vanilla AST/multi-cursor tools
    evil evil-collection evil-escape evil-args evil-exchange
    evil-indent-plus evil-lion evil-nerd-commenter evil-numbers evil-snipe
    evil-surround evil-embrace evil-textobj-anyblock evil-traces
    evil-visualstar evil-goggles exato evil-easymotion evil-multiedit
    iedit expreg evil-textobj-tree-sitter
    ;; git-only: evil-ts-obj ships its .el files under lisp/ in the repo,
    ;; so the default melpa recipe's file spec needs this override
    (evil-ts-obj :host github :repo "dvzubarev/evil-ts-obj"
                 :files ("lisp/*.el" "README.org"))
    ;; git-only: evil-markdown and evil-quick-diff have no melpa recipes
    (evil-markdown :host github :repo "Somelauw/evil-markdown")
    (evil-quick-diff :host github :repo "rgrinberg/evil-quick-diff")
    ;; git-only: codeberg rate-limits git smart-http on this network, so
    ;; upstream repos are redirected to their emacsmirror GitHub mirrors
    ;; (same practice Doom uses for these packages)
    (undo-fu :host github :repo "emacsmirror/undo-fu")
    (undo-fu-session :host github :repo "emacsmirror/undo-fu-session")
    (visual-fill-column :host github :repo "emacsmirror/visual-fill-column")
    (git-timemachine :host github :repo "emacsmirror/git-timemachine")
    (denote-wordcloud :host github :repo "emacsmirror/denote-wordcloud")
    ;; git-only: popon (flymake-popon's dependency) lives on codeberg with
    ;; no official mirror; this is a plain GitHub clone of it
    (popon :host github :repo "JasZhe/emacs-popon-mirror")
    ;; git-only: shift-number (evil-numbers's dependency) is codeberg-hosted;
    ;; the recipe must match MELPA's or straight warns of conflicting recipes
    (shift-number :host codeberg :repo "ideasman42/emacs-shift-number")
    ;; editing aids, undo, folding, formatting
    avy link-hint super-save sudo-edit
    ;; git-only: ws-butler is served from the NonGNU ELPA mirror branch,
    ;; packaged exactly like Doom's editor/whitespace module -- the
    ;; :local-repo keeps this checkout isolated from the shared nongnu_elpa
    ;; repository that hosts many other packages
    (ws-butler
     :host github
     :repo "emacsmirror/nongnu_elpa"
     :branch "elpa/ws-butler"
     :local-repo "ws-butler")
    ;; git-only: Doom's helpful fork (extra metadata in help buffers)
    (helpful :host github :repo "hlissner/helpful")
    vundo yasnippet yasnippet-capf
    ;; git-only: Doom's curated snippet collection
    (doom-snippets :host github :repo "doomemacs/snippets"
                   :files (:defaults "*"))
    auto-yasnippet vimish-fold evil-vimish-fold treesit-fold apheleia
    adaptive-wrap anzu evil-anzu jinx

    ;; ui: theme, modeline, icons, gutter, workspaces, sidebar, folding
    doom-themes solaire-mode hl-todo
    ;; git-only: indent-bars is served from its GitHub repo
    (indent-bars :host github :repo "jdtsmith/indent-bars")
    doom-modeline diff-hl dashboard persp-mode treemacs treemacs-nerd-icons
    treemacs-evil treemacs-projectile treemacs-magit treemacs-persp
    lsp-treemacs colorful-mode rainbow-delimiters
    ;; Git-only: Doom-like widgets for emacs-dashboard
    (doom-dashboard :host github :repo "emacs-dashboard/doom-dashboard"
                    :files (:defaults "banners"))

    ;; completion (vertico/consult/embark + corfu/cape)
    vertico orderless marginalia consult consult-dir embark embark-consult
    wgrep corfu cape nerd-icons-completion nerd-icons-corfu
    consult-yasnippet

    ;; org: Doom-default org + the Denote second brain.  org-contrib holds
    ;; the retired ob-/ox- libraries org requires on demand; htmlize is a
    ;; dependency-only entry (org export buffers).
    org-contrib org-modern org-appear toc-org htmlize ox-clip
    org-cliplink ob-async jupyter evil-org
    ;; git-only: denote/heading companion absent from every recipe repo
    (denote-merge :host github :repo "protesilaos/denote-merge")
    denote denote-silo denote-sequence denote-org denote-journal
    denote-journal-capture denote-menu denote-review denote-regexp
    denote-solo denote-explore consult-denote
    ;; markdown-ts-mode is built into Emacs 31 -- the GNU ELPA package of
    ;; the same name refuses to load on 31.x and must NOT be installed.
    markdown-mode markdown-toc edit-indirect

    ;; dev: lsp-mode/flymake/dape/apheleia tooling
    lsp-mode lsp-ui consult-lsp
    ;; git-only: flymake-popon lives on the doomelpa mirror
    (flymake-popon :host github :repo "doomelpa/flymake-popon")
    dape envrc

    ;; vc-projects: magit/forge porcelain, dired/dirvish, ibuffer
    magit forge code-review orgit orgit-forge git-link git-modes
    blamer magit-todos dirvish diredfl ibuffer-projectile ibuffer-vc

    ;; llm: Codex IDE, OpenCode ACP, and ChatGPT subscription via gptel.
    ;; Install explicit Git dependencies before their consumers to avoid
    ;; straight.el resolving different implicit recipes from MELPA.
    (shell-maker :host github :repo "xenodium/shell-maker")
    (acp :host github :repo "xenodium/acp.el")
    (codex-ide :host github :repo "dgillis/emacs-codex-ide")
    (agent-shell :host github :repo "xenodium/agent-shell")
    (gptel :host github :repo "karthink/gptel")

    ;; tools: notebooks, evaluation, lookup, LLM, pdf
    ein quickrun eros dumb-jump request
    ;; git-only gptel companions
    (gptel-quick :host github :repo "karthink/gptel-quick")
    (gptel-magit :host github :repo "ArthurHeymans/gptel-magit")
    (ob-gptel :host github :repo "jwiegley/ob-gptel")
    pdf-tools saveplace-pdf-view org-pdftools

    ;; lang: data formats, elisp dev, json, latex, markdown, nix, python,
    ;; qt, sh, web, yaml
    csv-mode json-mode json-snatcher
    highlight-quoted macrostep overseer elisp-def let-completion
    package-lint-flymake buttercup
    auctex auctex-cont-latexmk evil-tex cdlatex
    nix-mode nix-update nixos-options nix-ts-mode
    pip-requirements pipenv pyvenv conda nose python-pytest
    qml-mode qt-pro-mode
    ;; git-only: qml-ts-mode lives on GitHub
    (qml-ts-mode :host github :repo "xhcoding/qml-ts-mode")
    bash-completion emmet-mode haml-mode pug-mode slim-mode web-mode
    sass-mode stylus-mode sws-mode rainbow-mode yaml-mode

    ;; keybinds & terminal
    ace-window
    ;; git-only: ghostel + its evil extension come from the same repo
    (ghostel :host github :repo "dakra/ghostel")
    (evil-ghostel :host github :repo "dakra/ghostel"
                  :files ("extensions/evil-ghostel/*.el")))
  "Every external package this config installs, grouped by module.
Entries are package names (straight's default recipe repositories
resolve them) or explicit straight recipes for git-only packages.")

;; Install contract: one straight pass over the manifest.  Failures are
;; collected instead of aborting the loop, and any failure at all raises a
;; hard `error' at the end so batch runs exit non-zero and interactive
;; startup aborts with a message naming every failing package.
(declare-function straight-use-package "straight")

(let ((failures '()))
  (dolist (entry ar/packages)
    (condition-case err
        (straight-use-package entry)
      (error
       (push (format "straight-use-package %S: %s"
                     (if (consp entry) (car entry) entry)
                     (error-message-string err))
             failures))))
  (when failures
    (error "Package bootstrap FAILED (%d):\n%s"
           (length failures) (string-join failures "\n"))))

;; State hygiene: etc/ and var/ routing is owned entirely by
;; early-init.el.  What remains here is loading the user's custom-file,
;; which early-init.el already located in etc/.

;; Load immediately instead of on after-init-hook: the hook never runs in
;; batch, and the deferral existed for a stale package-manager reason only.
(load custom-file 'noerror 'nomessage)

;; Module wiring.  Every module lives in lisp/ with a descriptive name
;; chosen to never shadow a bundled library on `load-path'.
(declare-function ar/var-file "early-init")
(defvar ar/config-dir) ;; the real configuration root, set by early-init.el

(add-to-list 'load-path (expand-file-name "lisp" ar/config-dir))

;; The bundled use-package stays purely declarative:
;; `straight-use-package-by-default' is deliberately left nil, so the
;; use-package forms in the modules configure but never install --
;; installation is owned by the manifest pass above.
(require 'use-package)
(setopt use-package-expand-minimally t
        use-package-enable-imenu-support t)

;; Module load order is load-bearing: core-config defines the shared
;; helpers every later module uses, editor-config defines the
;; `ar/global-leader' and `ar/local-leader' definers, llm-config defines
;; the AI commands, and keybinds-config binds commands from all of them --
;; so this order must not change.
(defvar ar-modules
  '(core-config editor-config ui-config completion-config org-config
    dev-config tools-config lang-config vc-projects-config
    llm-config keybinds-config)
  "Module features this file loads, in this exact order.
`reload-init-file' re-evaluates these files after startup.")

;; Byte-compiled module cache.  Machine-written state under var/ per the
;; config's routing philosophy.  var/bytecode/ rides on `load-path' only
;; while EVERY cached .elc is current: `load-prefer-newer' compares suffix
;; variants within the first matching load-path entry only, so a cache
;; holding any stale copy is withheld entirely -- source loads this session
;; and the idle helper below rebuilds the cache for the next startup.
(defvar ar/bytecode-dir (ar/var-file "bytecode/")
  "Directory holding byte-compiled copies of the `ar-modules' files.")

(let ((lisp-dir (expand-file-name "lisp" ar/config-dir))
      (fresh t))
  (dolist (mod ar-modules)
    (let* ((name (concat (symbol-name mod) ".el"))
           (src (expand-file-name name lisp-dir))
           (dest (expand-file-name (concat name "c") ar/bytecode-dir)))
      (when (and (file-exists-p src)
                 (or (not (file-exists-p dest))
                     (file-newer-than-file-p src dest)))
        (setq fresh nil))))
  (when fresh
    (add-to-list 'load-path ar/bytecode-dir)))

(dolist (mod ar-modules)
  (require mod))

;; Keep the var/bytecode/ copies fresh: one-shot idle timer so batch runs
;; never fire it, and compilation in an `emacs --batch' subprocess so the
;; session never blocks.
(defun ar/force-load-manifest ()
  "Require every package in `ar/packages', swallowing failures.
Run only in batch compile subprocesses, before `batch-byte-compile':
defining macros of deferred packages (`transient-define-prefix',
`general-define-key', ...) must be known to the byte-compiler, or
forms like `(transient-define-prefix ar/foo ...)' compile into
runtime function calls that evaluate the name symbol as a variable."
  (dolist (entry ar/packages)
    (let ((name (if (consp entry) (car entry) entry)))
      (condition-case err
          (require name nil 'noerror)
        (error (message "ar/force-load-manifest: %S: %s"
                        name (error-message-string err)))))))

(defun ar/byte-compile-stale-modules ()
  "Byte-compile `ar-modules' whose cached .elc is missing or stale.
Compilation runs in an `emacs --batch' subprocess so the session never
blocks; output lands in the *ar-byte-compile* buffer."
  (ignore-errors (make-directory ar/bytecode-dir t))
  (when (file-writable-p ar/bytecode-dir)
    (let* ((lisp-dir (expand-file-name "lisp" ar/config-dir))
           (stale
            (delq nil
                  (mapcar
                   (lambda (mod)
                     (let* ((name (concat (symbol-name mod) ".el"))
                            (src (expand-file-name name lisp-dir))
                            (dest (expand-file-name (concat name "c")
                                                    ar/bytecode-dir)))
                       (when (and (file-exists-p src)
                                  (or (not (file-exists-p dest))
                                      (file-newer-than-file-p src dest)))
                         (cons src dest))))
                   ar-modules))))
      (when stale
        (apply #'start-process
               "ar-byte-compile" "*ar-byte-compile*"
               (concat invocation-directory invocation-name)
               "--batch"
               "--eval" (concat "(setq byte-compile-dest-file-function"
                                " (lambda (f) (or (cdr (assoc f '"
                                (prin1-to-string stale)
                                ")) f)))")
               "-l" (expand-file-name "early-init.el" ar/config-dir)
               "-l" (expand-file-name "init.el" ar/config-dir)
               "-f" "ar/force-load-manifest"
               "-f" "batch-byte-compile"
               (mapcar #'car stale))))))

(unless noninteractive
  (run-with-idle-timer 8 nil #'ar/byte-compile-stale-modules))

(provide 'init)
;;; init.el ends here
