# CLAUDE.md — Working instructions for Claude

This file tells Claude how I want it to work in this repository. It is read
automatically at the start of every session that works on this repo.

## About this project

**Support App — Addigy Prebuilt App Updates.** This surfaces Addigy Prebuilt
App update status inside the Root3 Support App, with a menu bar notification
badge when updates are pending — without needing an Addigy API key.

- The worker reads Addigy's local SQLite DB
  (`/Library/Addigy/ansible/prebuilt-apps/state.db`, table `prebuilt_apps`),
  counts `pending` rows, and writes the result into the Support App's
  preference domain (`nl.root3.support`).
- A LaunchDaemon runs the worker on load, on a 30-minute interval, and via
  `WatchPaths` whenever Addigy rewrites its state.
- See `README.md` for full architecture and the repository layout table.

### Development & testing environment

- I build and edit **locally on my own Mac**.
- I test on a dedicated **Mac mini** before anything is committed.
- These scripts run **as root** on managed Macs via Addigy, so mistakes have
  real fleet-wide impact. Treat every change as production-bound.

## Communication style

- **Be detailed.** Explain what a change does and why, not just that it's done.
- **Comment the code thoroughly.** Every script should carry comments that let
  another admin who opens it understand what each section does at a glance.
  Prefer clear, descriptive comments over terse ones — the audience is other
  IT technicians, not just me.

## Code conventions

- **Target platforms are macOS and iOS only.** Use only languages/tools native
  to those platforms:
  - **zsh** for the worker/installer scripts (matches the existing
    `scripts/*.zsh`).
  - **Swift / SwiftUI** for any app-side code.
  - Standard macOS tooling (`launchd`/`launchctl`, `defaults`, `plutil`,
    `sqlite3`, configuration profiles / `.mobileconfig`).
  - Do **not** introduce Python, Node, Bash-isms that assume Linux, or any
    dependency that isn't present on a stock Mac.
- **Testing is mandatory before committing.** Never commit untested code. If I
  need to run a test on the Mac mini myself, tell me exactly what to run and
  what a passing result looks like. If tests fail, say so plainly with the
  output — don't paper over it.
- Follow the conventions already present in the repo (file layout, reverse-DNS
  daemon labels, permissions like `root:wheel` / `755`).

## Git workflow

- **Commit messages:** simple, imperative one-liners
  (e.g. `Handle missing state.db gracefully`).
- **Always ask me before committing or pushing.** Make and test the changes,
  then stop and ask for approval before running `git commit` or `git push`.
- Never push to a branch other than the one I'm working on without explicit
  permission.

## Guardrails (important)

- **Be strictly security-aware.** These scripts run as root on managed
  endpoints. Actively watch for and flag:
  - anything running with elevated/root privileges,
  - world-writable paths or overly permissive file modes,
  - unquoted shell variables and unsanitized/untrusted input,
  - secrets, API keys, or credentials in code or logs.
  Explain the risk and **stop to ask me** before shipping anything sensitive.
- **When in doubt, stop and ask.** If you're unsure about an approach, a
  destructive action, or anything with fleet-wide impact, pause and check with
  me rather than guessing.
