# Benchmark: sync-me

## Metric

`operator_round_trips_to_success`: the number of turn pairs (agent message plus user reply) per walk step, from first render to a confirmed success observable. Lower is better. A failure click followed by a corrected retry counts as 2; a clean first success counts as 1.

Secondary: `steps_recovered_without_free_text`, the fraction of steps that reach success through the pre-filled options without the user pasting text into "Other". Higher is better.

Decide mode: `extra_turns_to_first_decision`, the number of user turns between an agent reply that holds decisions for the user and the first of those decisions the user answers. Lower is better. A user who answers a decision in the next turn scores 0. A turn that asks what the agent wants, asks for an interactive or one-at-a-time pass, or asks for a plainer explanation counts as 1 extra turn.

## Protocol

Walk mode: count turn pairs per step in live session transcripts, or in a dry run against `fixtures/valid_runbook.json`. Average over steps per session, then over sessions.

Decide mode: in session transcripts, find each agent reply that leaves one or more decisions for the user, using the decide hook matcher (`scripts/decide_stop_hook.sh`) to find candidates and a person to confirm each one. For each confirmed reply, count user turns until the user answers a decision, in prose or through an `AskUserQuestion` option. Report the share of replies that score 0 and the median. Compare versions before and after 3.2.0, and sessions with the decide hook on and off. Exclude plan interviews (the agent is gathering requirements, not asking for a ruling) and lost-context moments (those belong to catch-up).

## Results

| Version | Date | Observed | Evidence |
|---|---|---|---|
| v1.0 to v2.6.0 | 2026-07-05 to 2026-10-18 | not measured | Developed as `teach-me` inside a private skills repo; no repeat-session sample was recorded. |
| v3.0.0 | 2026-10-18 | not measured | Rename and standalone release. Smoke suite covers the runbook linter (5 cases), the notes config (5 cases) and the SKILL.md contract (2 checks). Unstick and catch-up have no measured outcome yet. |
| pre-3.2.0 baseline (decide) | 2026-06-03 to 2026-11-12 | 5 of 28 decision replies scored 0 (18 percent); 23 of 28 needed at least 1 extra turn | One maintainer's own Claude Code transcripts: 3196 sessions scanned, 265 candidate moments, 42 opened and classified by hand. Of the 42: 23 replies the user could not answer without an extra turn, 5 answered at once, 6 plan interviews, 5 lost-context moments, and 3 not assigned to these groups. The 28 are the 23 plus the 5. Limits: one user, a small hand-picked sample, the other 223 candidates unclassified, and turns were classified as zero or not, so no median was recorded. In the 5 answered at once, every decision had a recommendation, a two-way choice and its reason in the next sentence; reply length and how deep the decision sat in the reply did not differ from the 23. |
| v3.2.0 | 2026-11-12 | not measured | Decide mode and the optional Stop hook added. Smoke suite now runs 26 checks, including 11 decide-hook cases on synthetic transcripts, 1 plugin wiring check and 2 new notes-config cases. |
