# Changelog

## [Unreleased]

Skill version 3.2.0.

- Decide mode, the fourth mode: pulls the decisions waiting on the user out of the agent's reply, asks the root decision first, then asks each one through `AskUserQuestion` with a recommendation, what each option leads to and costs, and an "Explain this first" option.
- Optional Stop hook `scripts/decide_stop_hook.sh`, wired in the plugin and off by default. It blocks the stop once when a reply leaves decisions in prose without an `AskUserQuestion` call. Turn it on with `notes_path.sh --hook on` or a `decide_hook=on` config line.
- `notes_path.sh --set` now keeps other config lines instead of overwriting the file.
- Mode boundaries stated: unstick is one point, catch-up is the whole thread, decide is a question the user follows but cannot answer.
- Decide benchmark metric and a pre-release baseline; smoke suite grows from 12 to 26 checks.

## [1.0.0] - 2026-10-18

First standalone release (skill version 3.0.0; earlier versions shipped as `teach-me`).

- Three modes: unstick (legacy alias explain), catch-up and walk.
- Notes location is asked once per repo and stored in `.sync-me/config`: local `.sync-me/` by default, or a central folder.
- Self-contained writing rules replace external writing skills.
- Walk-mode runbook linter with schema and secret checks; smoke suite with 12 checks; concept-DOI guard test.
