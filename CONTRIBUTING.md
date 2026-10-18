# Contributing

## Reporting a bug

Open an issue with the request you gave the agent, the reply you expected and the reply you got. For the scripts, include the input file and the exit code.

## Proposing a change

Open an issue first for any change in behavior: a new mode, a new trigger, a change to the check rules. Small fixes can go straight to a pull request.

## Development

- `skills/sync-me/SKILL.md` is the specification. Read it before you change behavior.
- Tests: `bash skills/sync-me/tests/smoke.sh` and `python -m pytest tests -q`. Run both before every pull request.
- A script change needs a smoke case that fails without the change.
- Bump `version:` in SKILL.md and add a row to `skills/sync-me/tests/benchmark.md` for any behavior change.
- Keep SKILL.md self-contained: no references to other skills or private repos, and no em-dashes (the smoke suite checks both).

## Code style

Bash and Python standard library only. Match the style of the file you edit.
