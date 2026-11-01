# AGENTS.md

Personal vanilla Emacs 31.1 configuration. External packages are managed by
`straight.el`, with a central manifest in `init.el`.

## Ignore

Do not read, search, edit, or index any of the following:

- `eln-cache/`
- `etc/`
- `tests/`
- `var/`
- `LICENSE`
- `NOTICE`

`eln-cache/`, `etc/`, and `var/` are generated state; `tests/` is out of scope;
`LICENSE` and `NOTICE` are legal boilerplate.

## Layout

- `early-init.el`: runs before the first frame; routes state into `etc/` and
  `var/` natively (no no-littering).
- `init.el`: straight.el bootstrap, complete `ar/packages` manifest, and
  ordered module loader. Module load order is load-bearing.
- `lisp/*-config.el`: core, editor, ui, completion, org, dev, tools,
  lang, vc-projects, llm, and keybinds modules.
- `lisp/llm-config.el`: use-package declarations and helper commands for
  Codex IDE, agent-shell/OpenCode, and ChatGPT subscription/gptel.
- `lisp/keybinds-config.el`: all LLM leader bindings under `SPC o a`, alongside
  existing keybindings; uses `ar/global-leader` from editor-config.
- `snippets/`: yasnippet snippets.

## Conventions

- Every `.el` file uses `lexical-binding: t` and the standard Emacs Lisp
  header, Commentary, Code, and `provide` layout.
- Add packages and recipes only to the manifest in `init.el`. Module
  `use-package` forms must configure packages, not install them; do not add
  `:straight`, `:ensure`, or `:vc` there.
- Preserve the original module loading order, except for inserting
  `llm-config` immediately before `keybinds-config`.
- Keep keybindings in `lisp/keybinds-config.el`; do not bind keys inside
  `lisp/llm-config.el`. Use the existing `ar/global-leader` pattern and
  `:wk` which-key descriptions.
- Keep the surrounding comment density and naming conventions (`ar/` for
  personal symbols). Make targeted changes and retain unrelated settings.
- Do not duplicate gptel configuration in `tools-config.el` and
  `llm-config.el`; the latter owns the LLM backend configuration.

## LLM behavior and credentials

- Codex IDE runs `codex app-server`; use `codex login` for authentication.
- agent-shell is configured only for OpenCode using `opencode acp`; authenticate
  with `opencode auth login` rather than saving an API key in Emacs Lisp.
- gptel uses `gptel-make-openai-oauth` with the ChatGPT subscription (Codex)
  endpoint. It does not use a separately billed OpenAI API key.
- Do not commit login tokens, key files, OAuth cache files, personal prompts,
  or secrets. Do not enable permissive sandbox/approval options by default.
- `gptel` OAuth tokens are stored under `var/gptel/` using `ar/var-file`;
  treat that directory as sensitive machine state, never repository content.
- Do not launch agents, MCP bridges, or authentication during Emacs startup;
  those operations require explicit interactive commands or user decisions.
- The optional Codex Emacs MCP bridge must prompt before starting and its
  tool calls must require user approval.
