# Upstream pin: mattpocock/skills `teach`

`sync-me` ports selected teaching rules from [mattpocock/skills](https://github.com/mattpocock/skills) `skills/productivity/teach/SKILL.md` (MIT, © its authors). This file is the single record of which upstream version the port matches and what happened to each upstream idea. Rules are ported in our own wording; no upstream text is copied into this repo.

Scope difference: upstream teaches a *topic* over many sessions (mission, HTML lessons, reference sheets, learning records). `sync-me` explains an agent's own work (unstick mode, legacy name explain), rebuilds lost session context (catch-up mode), or guides an operator through a task the agent cannot run (walk mode). Only the learning-science rules carry over; the curriculum machinery does not.

pinned_sha: 321658273cb1d20b76026717d027d505790106d4
pinned_version: n/a
pinned_date: 2026-10-03

## Drift trigger

To check for drift, compare upstream `SKILL.md` at HEAD with the pinned commit. Classify each change (conflict, new pattern, wording only), update the table below, port adopted rules into `SKILL.md`, and only then bump `pinned_sha` and `pinned_date`. Upstream has no `version:` frontmatter, so `pinned_version` stays `n/a`.

## Mapping: upstream sections to sync-me

Outcome values: **existing** (already covered), **adopted** (ported in v2.5), **partial**, **rejected** (reason given), **deferred** (reason given).

| Upstream idea | Outcome | sync-me rule / reason |
|---|---|---|
| Teaching workspace: `MISSION.md`, `RESOURCES.md`, `lessons/`, `reference/`, `assets/` | rejected | Curriculum machinery for a topic course. sync-me is grounded by the task at hand; the note dir `<notes dir>/` is the only state. |
| `learning-records/` read first to find the zone of proximal development | adopted | Unstick step 0 (and catch-up step 0): read prior `<notes dir>/` notes before mapping; skip settled parts, go deeper where a prior note recorded confusion. |
| `NOTES.md` for how the operator wants to be taught | adopted | `<notes root>/NOTES.md` (one operator, all repos): preferred analogies, pace, formats, things to avoid. Read at start, append when a preference is stated. |
| Fluency vs storage strength; "Got it" can be illusory mastery | adopted | Explain step 3: for a part the operator must act on later, replace "Got it" with a recall check (pick the true statement). |
| Retrieval practice | adopted | Same recall check; the operator retrieves, the agent does not restate. |
| Quiz answers same length, no formatting clue to the right one | adopted | Recall-check options: same word count, same shape, correct one not first by default. |
| Spacing (practice over time) | deferred | One recall question on a prior note's term at session start would do it; not added until the operator asks (cost: one extra turn per session). |
| Interleaving | rejected | Skills practice only; unstick and catch-up modes have no practice set. |
| Working memory is small; lessons short | existing | Explain step 2: at most 5 short lines per part. |
| Never trust parametric knowledge; cite every claim | existing | Explain step 2: every claim needs evidence (file:line, output, commit). |
| Glossary kept and adhered to in every lesson | existing | `CONTEXT.md` glossary via the `grill` convention. |
| Mission grounding; ask why before teaching | existing | The task is the mission. If the operator asks to be taught something not tied to current work, ask the why once. |
| Tight, immediate, automatic feedback loop | existing | Walk mode steps 2-4: verify each step with a concrete observable before advancing. |
| Knowledge first, then practice | existing | Walk mode: explain the step, operator acts, agent verifies. |
| Beautiful HTML lessons, Tufte layout, open via CLI | rejected | Chat-native skill; `asd-ste100-lens` + Golden rule govern text. |
| Reference documents outlive lessons | partial | The dated note already holds terms and decisions, not implementation detail. No separate reference dir. |
| Wisdom: delegate to communities | rejected | Out of scope. |
| Reminder to ask follow-up questions | existing | Interactive by construction; no question cap. |
| `disable-model-invocation: true`, `argument-hint` | partial | `argument-hint` added. Model invocation stays enabled: "explain what you're doing" must trigger mid-task. |
