# Benchmark: sync-me

## Metric

`operator_round_trips_to_success`: the number of turn pairs (agent message plus user reply) per walk step, from first render to a confirmed success observable. Lower is better. A failure click followed by a corrected retry counts as 2; a clean first success counts as 1.

Secondary: `steps_recovered_without_free_text`, the fraction of steps that reach success through the pre-filled options without the user pasting text into "Other". Higher is better.

## Protocol

Count turn pairs per step in live session transcripts, or in a dry run against `fixtures/valid_runbook.json`. Average over steps per session, then over sessions.

## Results

| Version | Date | Observed | Evidence |
|---|---|---|---|
| v1.0 to v2.6.0 | 2026-07-05 to 2026-10-18 | not measured | Developed as `teach-me` inside a private skills repo; no repeat-session sample was recorded. |
| v3.0.0 | 2026-10-18 | not measured | Rename and standalone release. Smoke suite covers the runbook linter (5 cases), the notes config (5 cases) and the SKILL.md contract (2 checks). Unstick and catch-up have no measured outcome yet. |
