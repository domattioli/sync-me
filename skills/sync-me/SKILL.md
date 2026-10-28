---
name: sync-me
version: "3.1.0"
benchmark: operator_round_trips_to_success
argument-hint: "What lost you, should I catch you up, or walk you through a task?"
description: Interactive, grill-style teaching session for a person working with a coding agent, in three modes. UNSTICK (legacy alias "explain") finds the one point that lost the user, maps the likely uncertainty branches, explains one part per turn and checks recall per branch. CATCH-UP rebuilds the context of a long session the user missed (handoffs, git, PRs, notes, transcript), shows a 3-line card (goal, state, next decision), then teaches it top-down. WALK guides the user through a task only they can do (dashboard clicks, DNS, credential-bound or physical steps), one verified step at a time with pre-filled success and failure options. Reads prior notes first and writes a dated note per session. Triggers "sync me", "teach me", "explain X", "wait", "lost me", "why did you", "catch me up", "I'm lost, start over", "coming in cold", "walk me through", and the legacy names "teach-me" and "machine-teaching".
---

# sync-me

Three modes, one purpose: the user ends up understanding, or having done, something the agent could not hand over as plain output.

| Mode | Who acts | Trigger | Output |
|---|---|---|---|
| **unstick** (legacy alias: explain) | agent explains one point that lost the user | "teach me", "explain X", "wait", "lost me", "why did you" | answers and a dated note |
| **catch-up** | agent rebuilds the context, then teaches it top-down | "sync me", "catch me up", "I'm lost, start over", "coming in cold", "where are we, I'm lost" | 3-line card, answers and a dated note |
| **walk** | user acts, agent guides and verifies | "walk me through", a task the agent cannot execute | one verified step per turn |

Pick the mode from the request. If it is unclear whether one point or the whole thread was lost, ask once with `AskUserQuestion`: "One point lost you" or "I lost the whole thread". The legacy names "teach-me", "explain" and "machine-teaching" still trigger this skill.

## Where notes go

On first use in a repo, run `scripts/notes_path.sh`.

- Exit 0: it prints the notes directory. Use it.
- Exit 4 (no config yet): ask the user once with `AskUserQuestion`. Options: "Local `.sync-me/` in this repo (Recommended)" and "A central folder I choose" (the user types an absolute path in Other). Then run `scripts/notes_path.sh --set local` or `scripts/notes_path.sh --set <path>`. Never ask again in that repo.

The answer is stored as one line, `notes_root=local` or `notes_root=<path>`, in `<repo>/.sync-me/config`. When that file is missing, a user-wide `~/.config/sync-me/config` (same format) applies. Local notes go to `<repo>/.sync-me/`; central notes go to `<path>/<repo>/`. The preferences file `NOTES.md` sits at the notes root (`scripts/notes_path.sh --root`). Below, `<notes>` means the notes directory and `<root>` the notes root.

## Writing rules (all modes)

Every question, answer, step and note the user reads follows these rules. Never compress into fragments: the user is learning, and dropped words cost understanding.

1. Answer first. Put the point in the first sentence, then the evidence.
2. One idea per sentence, one topic per chunk. At most 5 short lines per part.
3. Plain words. Use the same word for the same thing every time. Define a term the first time you use it.
4. Active voice, present tense where possible. Say who does what.
5. Keep exact numbers, names, paths and commands. Do not round or paraphrase them.
6. No filler, no praise, no recap at the end, no closing pleasantries.
7. No em-dashes. No "it's not X, it's Y" framing. No stacked hedges; state the uncertainty once, with its reason.
8. Always interactive. Ask every question through `AskUserQuestion`, never in prose. Never answer for the user, and never move to the next part before the user answers.

## Unstick mode

Modeled on a grill session, pointed the other way: a grill questions the user's plan; unstick makes sure the user understands the agent's. Use it when the user was following along and one point lost them.

Before step 0, **find the point.** Ask once with `AskUserQuestion` which point lost the user. Options: the 2-3 most likely candidates from recent turns (the last decision, the last command or diff, the last term the agent used), labelled the way the user would say them, plus "Other". Skip this question only when the request already names the point. Then run steps 0-7 narrowed to that point.

0. **Read what the user already knows.** Open `<notes>/*.md` (prior notes) and `<root>/NOTES.md` (teaching preferences). Skip parts a prior note settled; go deeper where a prior note recorded confusion. Follow stated preferences (analogy style, pace, format).
1. **Map the uncertainty branches first.** One line per part the user needs, in order (for example "3 parts: what changed, why, what could break"). For each part, anticipate where the user is likely to stall. Mark the part that needs a decision from the user.
2. **One part per turn, always interactive.** Never explain two parts in one turn, and never put the whole map in one reply. A preference in `NOTES.md` may change the check in step 3, never this rule. Every claim needs evidence (file:line, command output, commit).
3. **Check, do not assume.** End each part with an `AskUserQuestion`. Default options: "Got it", the 1-3 most likely confusions, and "Other". Put the recommended answer first when the part asks for a decision. **Recall check** when the user must act on this part later (a command to run, a rule to apply, a term to use): no "Got it" option. Instead give 3-4 statements about the part, one true; the user picks. All options have the same length and shape, the true one is not first by default, and no formatting hints the answer. "Got it" measures fluency in the moment; recall builds retention.
4. **On confusion,** re-explain the same part a different way (an analogy, a smaller example, a picture in words). After two misses on one part, ask what is unclear in the user's words.
5. **Explore instead of asking** when the codebase or logs can answer.
6. **Write the note as you go.** Create `<notes>/YYYY-MM-DD-<topic>.md` on the first settled part, and append after each part: the term or decision, a one-line meaning, an evidence link. No implementation detail the user did not ask for.
6b. **Record preferences.** When the user says how they want to be taught ("skip the analogies", "show the command first", "shorter"), append one dated line to `<root>/NOTES.md`. Read it at step 0 of every later session.
7. **Close** with one line: what the user now knows and any decision still theirs. Then write the session-end note.

There is no question cap. Keep asking until every mapped part is settled, no confusion is open and no decision is unanswered. A new confusion or term adds a part to the map. Stop early only when the user says so.

## Catch-up mode

Use it when the user comes in cold after a long session: a break, a context reset, a session that ran while they were away. Unstick narrows to one point; catch-up rebuilds the whole thread, then teaches it top-down. A plain status request ("where are we") gets a short status answer; catch-up starts when the user says they are lost.

0. **Rebuild the context before speaking.** Read, in this order, whatever exists: `.claude/handoffs/` (newest first), `git log` since the last handoff or the branch point, `git status` and the current branch, open PRs (`gh pr list`), `<notes>/` and `<root>/NOTES.md`, then the transcript of this session. Every claim in the card and the parts needs evidence from one of these (file:line, commit, PR number). Do not ask the user what happened; the sources answer that.
1. **Card first.** Three lines: the goal of the work, the current state (done, in flight), and the next decision that waits on the user. If nothing waits on the user, the third line says so.
2. **Map top-down.** Four parts in this order: goal, what is done, where we are now, what waits on the user. Mark the part that holds the decision. Name the map in one line, then start on part 1.
3. **One part per turn.** Same rule as unstick step 2. Explain why, not only what: a decision gets its reason, a change gets the problem it solved, a state gets what put it there.
4. **Check, do not assume.** As in unstick step 3. Default options: "Got it", "Drill into this", the 1-2 most likely confusions, "Other". "Drill into this" adds a sub-part and explains it next turn. Use a recall check only for a term or decision the user must act on.
5. **On confusion,** re-explain the same part a different way. After two misses, ask what is unclear in the user's words.
6. **Write the note as you go,** as in unstick steps 6 and 6b.
7. **Close** with one line: what the user now knows and the decision that is theirs, if any. Then write the session-end note.

Same question policy as unstick: no cap; stop early only when the user says so.

## Walk mode

The agent cannot click the button, so it teaches the user to click it, verifies the click worked, and debugs when it did not.

### When to use

- Cloud dashboard configuration (DNS records, access policies, environment variables, billing) with no API or CLI path available to the agent.
- Physical actions (plug in a device, read a serial number off hardware).
- Anything that needs a secret, credential or payment method the agent must never hold or see.
- A runbook with an order-critical step, or with more than one plausible failure per step.
- Interactive debugging where the next action depends on which error the user hits.

### When not to use

- The agent can do it itself (it has the tool, API or credential). Do it; do not narrate it as a human task.
- A single trivial instruction with no failure branch ("click Save"). A plain instruction is enough.
- Refining a plan before execution (a grill session), understanding the agent's plan (unstick), or rebuilding lost context (catch-up). Walk starts once the plan is settled.

### Failure modes walk mode replaces

1. **Runbook dump.** A 10-step wall of instructions. The user loses their place, does step 4 before step 2, or skips a step whose order mattered.
2. **Open-ended debugging loop.** The user reports "it didn't work", and the agent spends 2-3 round trips finding out which known failure occurred.

Pre-filled failure options make most debugging a single click, and per-step verification catches a skipped or failed step before it compounds.

### Walk protocol

1. **Step map, once.** One line per step, titles only, order-critical steps flagged. Example: "5 steps: verify build, create Access app, generate secret locally, point DNS, verify end-to-end."
2. **Render exactly one step** with `AskUserQuestion`: exact navigation path, exact values, exact command. Options: the success outcome (phrased as a concrete observable), each plausible failure labelled the way the user would describe it, and "Other" for pasted error text. Header: `Step N of M`. Worked example: `tests/fixtures/valid_runbook.json`.
3. **Verify before advancing.** The success option asserts a checkable observable ("newest deployment shows Success and SHA <sha>", "curl -I returns 302"). Never advance on a guess.
4. **Diagnose and retry the same step.** Read the error, name the likely cause, give a corrected instruction, and re-render with header `Step N of M (retry)`. After the same failure twice, stop guessing: ask for a screenshot or the exact dashboard text, or suggest a check one level up (permissions, browser, propagation delay).
5. **Order-critical steps.** Flag them in the map and in the step text, and spell out in full what breaks if done out of order.
6. **Secret hygiene.** The agent never emits a secret, not even a realistic placeholder. Give the user a command to run in their own terminal (`openssl rand -hex 32`), name the field to paste it into, and verify that the field shows a saved value, never the value itself. Never ask the user to paste a secret into the chat.
7. **Numbering.** If the step count changes mid-run, say so plainly.
8. **Close** with the end state (what is live, what to check again later). Then write the session-end note.

## Session-end note (all modes)

After the close, write 2-4 lines:

- **Gap:** the concept or distinction the user was missing, or the friction point the session found.
- **Fix:** what resolved it (the explanation, analogy, step or evidence that worked).

Append it to the dated note in unstick and catch-up. In walk mode, put it in the chat, and in the dated note if one exists. If no gap came up, write one line that says so.

## Scripts

```
scripts/notes_path.sh [--root | --set local|<path>]   # resolve or set the notes location
scripts/validate_runbook.sh <runbook.json>            # lint a pre-authored walk runbook
```

`notes_path.sh` exit codes: 0 ok, 2 usage error, 4 no config yet (ask the user).

`validate_runbook.sh` exit codes: 0 valid; 1 schema error (missing field, empty failures, `order_critical` without `order_note`, duplicate id); 2 usage error (no arg, missing file, no `jq`, invalid JSON); 3 blocked, a step contains a real-looking secret (takes priority).

Runbook schema: `{"title": str, "steps": [{"id": int, "title": str, "instruction": str, "order_critical": bool, "order_note": str, "success": {"label": str, "assert": str}, "failures": [{"label": str, "diagnosis_hint": str}]}]}`. `order_note` is required when `order_critical` is true.

## Hard stops

| Condition | Behavior |
|---|---|
| The agent has direct access to do the task | Do it. Walk mode is for tasks the agent cannot execute. |
| A step would need the user to paste a secret into chat | Redesign the step so it verifies a saved-state observable. |
| `validate_runbook.sh` exits 3 | Fix the step text before using the runbook. |
| Same failure twice after a corrected retry | Ask for a screenshot or exact text; no third blind retry. |

## Files

- `scripts/notes_path.sh`: notes location config (ask once, remember).
- `scripts/validate_runbook.sh`: schema and secret-hygiene linter for walk runbooks.
- `tests/smoke.sh`: runbook linter scenarios, notes config scenarios, SKILL.md contract.
- `tests/fixtures/`: a full 5-step Cloudflare Pages, DNS and Access runbook, and a schema-invalid runbook.
- `tests/benchmark.md`: benchmark definition and baseline.
- `references/upstream-teach.md`: pinned mapping against mattpocock/skills `teach`.

## Version history

- **v3.1.0** (2026-10-28): operator rule: always interactive, questions only through `AskUserQuestion`, never prose.
- **v3.0.0** (2026-10-18): renamed teach-me to sync-me and moved to a standalone repo. Self-contained: inline writing rules replace external writing skills. Notes location is asked once per repo and stored in `.sync-me/config` (local `.sync-me/` by default, or a central path). Legacy triggers kept.
- **v2.6.0** (2026-10-18): explain renamed unstick; catch-up mode added.
- **v2.5** (2026-10-03): recall checks, prior-note read and preferences file ported from upstream `teach`.
- **v2.0** (2026-09-26): machine-teaching renamed teach-me; explain mode added beside walk.
- **v1.0** (2026-07-05): walk mode.
