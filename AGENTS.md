# Agent guide

This file is for any coding agent (Claude Code, Codex, …). Claude Code also
loads `CLAUDE.md` automatically.

Read these first:

1. `CLAUDE.md` covers the owner's rules, set-aside plugins, categories,
   GitHub conventions and branch protection.
2. `docs/dev/ARCHITECTURE.md` explains how plugins, game-common,
   sudoku-common, the module guard, i18n, menus, Dashboard and Plugin Manager
   fit together.
3. `docs/dev/RELEASE.md` gives the exact release order, onboarding and
   retiring.
4. `docs/dev/TESTING.md` covers specs, i18n, renders, speed, memory,
   real-install tests and the device.
5. `docs/dev/PITFALLS.md` lists everything that already broke once.
6. `docs/dev/NEW_PLUGIN.md` is the checklist and reference plugins.
7. `scripts/dev/README.md` documents the developer tools (specs, i18n check,
   renders, probes, release helpers).

Non-negotiable:

- Nothing is published (push, tag, repo creation, archive, delete) without
  the owner's explicit GO. Reply to the owner in French.
- Never stage `arrowwords.koplugin` or `kakuro.koplugin`.
- Never commit work from another session.
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  (or your agent's equivalent).
