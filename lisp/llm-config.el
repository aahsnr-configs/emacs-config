;;; llm-config.el --- Codex IDE, OpenCode ACP, and ChatGPT for Emacs -*- lexical-binding: t; -*-

;;; Commentary:

;; This module configures three explicitly invoked LLM clients:
;; - `codex-ide': native Codex app-server sessions and editor context.
;; - `agent-shell': only OpenCode, via Agent Client Protocol (ACP).
;; - `gptel': ChatGPT Plus/Pro OAuth (Codex endpoint, not API billing).
;;
;; Package installation is owned by `ar/packages' in init.el; no :straight
;; or :ensure directives belong in this module.  Leader keybindings live
;; exclusively in keybinds-config.el, under SPC o a.
;;
;; External programs: codex, opencode, curl and git; python3 and
;; emacsclient are optional for the Codex Emacs MCP bridge.
;; Authenticate separately with `codex login' and `opencode auth login'.
;; For ChatGPT, call `ar/llm-gptel-login' on first use.
;;
;; Loading this module does not start agent processes, MCP servers, or login.
;; Note: keep gptel's configuration in this module alone; remove any
;; duplicate `use-package gptel' configuration from tools-config.el.

;;; Code:

(defun ar/llm-check-prerequisites ()
  "Report external program availability for the configured LLM clients.
This does not check login state, credentials, or network availability."
  (interactive)
  (with-help-window "*LLM prerequisites*"
    (princ "LLM integration: external executable checks\n\n")
    (dolist (program '("codex" "opencode" "curl" "git"
                       "python3" "emacsclient"))
      (princ (format "%-13s %s\n" program
                     (or (executable-find program) "NOT FOUND"))))
    (princ "\npython3 and emacsclient are optional for the Codex MCP bridge.\n")
    (princ "Codex: codex login\n")
    (princ "OpenCode: opencode auth login\n")
    (princ "ChatGPT: M-x ar/llm-gptel-login\n")))

(defun ar/llm--maybe-add-opencode-to-path ()
  "Expose a default user OpenCode installation if it is not already on PATH."
  (unless (executable-find "opencode")
    (let* ((dir (expand-file-name "~/.opencode/bin"))
           (binary (expand-file-name "opencode" dir)))
      (when (file-executable-p binary)
        (add-to-list 'exec-path dir)
        (setenv "PATH" (concat dir path-separator
                               (or (getenv "PATH") "")))))))

;; Codex IDE: app-server renderer and editor-aware context.
;; https://github.com/dgillis/emacs-codex-ide
(use-package codex-ide
  :commands (codex-ide codex-ide-menu)
  :custom
  (codex-ide-approval-policy "on-request")
  (codex-ide-sandbox-mode "workspace-write")
  ;; Ask before starting the optional MCP bridge; do not auto-approve its tools.
  (codex-ide-want-mcp-bridge 'prompt)
  (codex-ide-emacs-bridge-require-approval t)
  ;; Respect the model configured for the Codex CLI.
  (codex-ide-model nil)
  (codex-ide-reasoning-effort "medium")
  (codex-ide-emacs-context-policy 'all)
  (codex-ide-diff-auto-display-policy 'approval-only)
  (codex-ide-buffer-display-when-approval-required t)
  (codex-ide-session-enable-visual-line-mode t)
  ;; Avoid retaining potentially sensitive source and prompts in debug logs.
  (codex-ide-logging-enabled nil))

;; agent-shell depends on ACP and shell-maker, both installed by the manifest.
;; https://github.com/xenodium/agent-shell
(defun ar/llm-opencode-new ()
  "Start a new OpenCode ACP session in agent-shell."
  (interactive)
  (require 'agent-shell)
  (call-interactively #'agent-shell-opencode-start-agent))

(use-package agent-shell
  :commands (agent-shell agent-shell-opencode-start-agent)
  :init
  (ar/llm--maybe-add-opencode-to-path)
  :config
  ;; Display only OpenCode in the agent picker; no other agents offered.
  (setq agent-shell-agent-configs
        (list #'agent-shell-opencode-make-agent-config)
        agent-shell-preferred-agent-config 'opencode
        agent-shell-opencode-acp-command '("opencode" "acp")
        ;; Reuse OpenCode's own credential store (opencode auth login).
        agent-shell-opencode-authentication
       (agent-shell-opencode-make-authentication :none t)))

;; gptel OAuth does not require an OpenAI Platform API key.  It uses the
;; ChatGPT subscription Codex endpoint, not the ChatGPT website/history.
;; https://github.com/karthink/gptel
(defun ar/llm-gptel-login ()
  "Log into the gptel ChatGPT subscription backend on demand."
  (interactive)
  (require 'gptel)
  (require 'gptel-openai-oauth)
  (call-interactively #'gptel-openai-oauth-login))

(defun ar/llm-gptel-menu ()
  "Open gptel's transient menu on demand."
  (interactive)
  (require 'gptel)
  (require 'gptel-transient)
  (call-interactively #'gptel-menu))

(defun ar/llm-gptel-rewrite ()
  "Rewrite a selected region through gptel on demand."
  (interactive)
  (require 'gptel)
  (require 'gptel-rewrite)
  (call-interactively #'gptel-rewrite))

(defun ar/llm-gptel-add ()
  "Add a buffer, region, or selected Dired files to gptel context."
  (interactive)
  (require 'gptel)
  (require 'gptel-context)
  (call-interactively #'gptel-add))

(use-package gptel
  :commands (gptel gptel-send)
  :custom
  (gptel-default-mode 'org-mode)
  (gptel-use-header-line t)
  (gptel-confirm-tool-calls t)
  :config
  (require 'gptel-openai-oauth)
  ;; Keep OAuth credentials in the existing var/ state tree.  This is an
  ;; upstream internal variable; review on gptel updates.
  (setq gptel--openai-oauth-token-file
        (ar/var-file "gptel/openai-oauth-token"))
  ;; Change to 'device when authenticating over SSH with no localhost callback.
  ;; (setq gptel-openai-oauth-login-method 'device)
  (setq gptel-backend (gptel-make-openai-oauth "ChatGPT subscription")
        gptel-model 'gpt-6-sol))

(provide 'llm-config)
;;; llm-config.el ends here
