# AGENTS.md

Instructions for a coding agent working on this repo.

- The skill lives in `skills/sync-me/`. `plugins/sync-me/skills/sync-me` is a symlink to it; do not copy files there.
- Run `bash skills/sync-me/tests/smoke.sh` and `python -m pytest tests -q` before you commit.
- SKILL.md must stay self-contained (no external skill names, no private paths, no em-dashes).
- Never put a real or realistic secret in a fixture. Build fake tokens at runtime, as `tests/smoke.sh` does.
- Releases are tag pushes (`.github/workflows/release.yml`). Do not tag or publish without the maintainer.
- After the first Zenodo archive, set `CONCEPT_DOI` in `tests/test_release_metadata.py` and add the DOI to `CITATION.cff` and the README.
- Do not create a CLAUDE.md file.
