# sync-me

![License](https://img.shields.io/badge/license-Apache--2.0-blue)
[![Tests](https://github.com/domattioli/sync-me/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/domattioli/sync-me/actions/workflows/tests.yml)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23459402.svg)](https://doi.org/10.5281/zenodo.23459402)

A Claude Code skill that runs an interactive, grill-style teaching session for a person working with a coding agent. It maps the user's likely uncertainty branches, anticipates the difficulty points, and checks recall per branch before it moves on.

## Contents

1. [Motivation](#1-motivation)
2. [Installation](#2-installation)
3. [Usage](#3-usage)
4. [Method](#4-method)
5. [Benchmarks](#5-benchmarks)
6. [Limitations](#6-limitations)
7. [Future work](#7-future-work)
8. [Documentation](#8-documentation)
9. [Contributing](#9-contributing)
10. [Reuse](#10-reuse)
11. [License](#11-license)

## 1. Motivation

A coding agent can change many files, make design decisions and run long sessions while the user watches part of the time. The user then has to act on that work: approve a plan, run a command, configure a dashboard. A summary tells the user what happened. It does not show whether the user understood it.

Existing tools summarize or re-explain:

| Tool | What it does | What it does not do |
|---|---|---|
| Claude Code `/recap` (built in) | One recap line, at most 400 characters, for the current session | No questions, no checks, no earlier sessions |
| mattpocock/skills `wait-what` (296,068 stars for the collection) | One-shot re-explanation of the last answer | No map of the open questions, no recall check |
| everyinc/compound-engineering-plugin `ce-explain` (25,584 stars) | Explains code or a change on request | No per-branch checks, no notes |
| kirilxd/claude-tutor (142 stars) | Tutoring on a topic | Not tied to the agent's own work in progress |
| Explanatory and Learning output styles | Change the tone of every reply | Not a session with a goal, a map and checks |

Star counts were measured with the GitHub API on 2026-10-18.

sync-me treats understanding as something to verify. It asks which point lost the user, explains one part per turn with evidence, and ends each part with a question. When the user must act on a part later, the question is a recall check: several statements of equal shape, one of them true.

## 2. Installation

```
claude plugin marketplace add domattioli/sync-me
claude plugin install sync-me@sync-me
```

Manual install: copy `skills/sync-me/` to `~/.claude/skills/sync-me/`. Walk mode's linter needs `jq`.

## 3. Usage

| Say | Mode | Result |
|---|---|---|
| "wait, lost me", "explain X", "why did you", "teach me" | unstick | finds the confusing point, teaches it one part per turn |
| "sync me", "catch me up", "coming in cold" | catch-up | 3-line card (goal, state, next decision), then the thread top-down |
| "walk me through" | walk | one verified step per turn for a task only you can do |
| "what do you need from me", "help me decide", "your calls" | decide | the decisions the agent left for you, asked one at a time with a recommendation and what each option costs |

Use unstick when one point lost you, catch-up when the whole thread did, and decide when you follow the thread but cannot answer what the agent asked. The old names `teach-me`, `explain` and `machine-teaching` still trigger the skill.

### Where notes go

Each session writes a dated note, and the skill reads earlier notes before it starts, so a later session builds on what you already know. On first use in a repo, sync-me asks once where to keep these notes:

- **Local (default):** `<repo>/.sync-me/`.
- **Central:** a folder you choose. Notes for each repo go to `<folder>/<repo>/`.

The answer is saved as one line (`notes_root=local` or `notes_root=/abs/path`) in `<repo>/.sync-me/config`. If that file is missing, `~/.config/sync-me/config` applies, so one line there sets a central store for every repo. Teaching preferences ("skip analogies", "shorter") are kept in `NOTES.md` at the notes root. To change the choice, run:

```
skills/sync-me/scripts/notes_path.sh --set local
skills/sync-me/scripts/notes_path.sh --set /abs/path/to/notes
```

Add `.sync-me/` to `.gitignore` if the notes should stay out of version control.

### Decide hook (optional, off by default)

Agents often end a long reply with decisions for you written as prose. The decide hook is a Claude Code Stop hook that catches this: when a reply leaves decisions in prose and the agent asked no `AskUserQuestion` question in that turn, the hook blocks the stop once and tells the agent to run decide mode. It never blocks twice in a row.

A plugin install ships the hook, but it does nothing until you turn it on. To turn it on for one repo, or for every repo:

```
skills/sync-me/scripts/notes_path.sh --hook on
skills/sync-me/scripts/notes_path.sh --hook on --user
```

Each command writes the line `decide_hook=on` to the same config file the notes location uses (`<repo>/.sync-me/config`, or `~/.config/sync-me/config` with `--user`). You can also add that line by hand. A repo line wins over the user-wide line, so `--hook off` in one repo turns it off there. `SYNC_ME_DECIDE_HOOK=off` in the environment turns it off for a session. The hook needs `jq`; without `jq` it does nothing.

A manual install (copying `skills/sync-me/`) gets no hook. To add it, put a Stop hook in your Claude Code settings whose command is `bash ~/.claude/skills/sync-me/scripts/decide_stop_hook.sh`, then turn it on as above.

The matcher favors precision. It fires on lead-ins such as "Your calls:", "Decide:", "Decisions for you", "I need three decisions from you", "until you rule on" and "Which do you want?", and on two or more list items that end with a question mark. It ignores text in code and in quotation marks, and it does not fire on a lone trailing "Want me to...?".

## 4. Method

Unstick and catch-up follow the same loop:

1. Read prior notes and preferences.
2. Map the parts the user needs and the likely point of difficulty in each.
3. Explain one part per turn, at most 5 short lines, with evidence (file and line, command output, commit).
4. End the part with a question. The default options are "Got it" and the most likely confusions. A part the user must act on gets a recall check instead.
5. On a miss, re-explain the part a different way. After two misses, ask the user to say what is unclear.
6. Append the settled part to the dated note. Close with a 2-4 line note naming the gap and what fixed it.

There is no question cap. The session ends when every part is settled or the user stops it. Catch-up first rebuilds the context from handoffs, git history, open pull requests, prior notes and the transcript, and it states no claim without a source.

Walk mode renders one step per turn as a multiple-choice question. The options are the success observable and the known failure branches. The agent advances only after the success observable is confirmed, retries the same step on failure, and escalates after two identical failures. The agent never emits a secret; the user generates it in their own terminal. `scripts/validate_runbook.sh` lints a pre-written runbook and refuses one that contains a real-looking key.

Decide mode collects every decision that waits on the user from the agent's last reply and the turns since the user last answered, including implied ones such as a recommendation that needs sign-off. It answers from the codebase what it can, states and asks first any root decision the others depend on, and then asks one decision per `AskUserQuestion` call. Each question says what is decided and why, what each option leads to and costs, and what happens if the user picks nothing. The recommended option comes first. An "Explain this first" option switches to unstick for that one decision. The design follows a hand review of decision replies in real sessions: the ones answered at once gave a recommendation, a two-way choice and the reason beside it (see `skills/sync-me/tests/benchmark.md`).

The recall check and the prior-note read adapt ideas from mattpocock/skills `teach` (see `skills/sync-me/references/upstream-teach.md`).

## 5. Benchmarks

The target metric is `operator_round_trips_to_success`: turn pairs per walk step until success is confirmed. It has not been measured yet; `skills/sync-me/tests/benchmark.md` holds the protocol. Decide mode's metric is `extra_turns_to_first_decision`: user turns between a reply that holds decisions and the first decision answered. A hand-classified pre-release sample from one user's sessions found 5 of 28 such replies answered with no extra turn; the benchmark file states the limits of that sample. The smoke suite (`bash skills/sync-me/tests/smoke.sh`) runs 26 deterministic checks: 5 runbook-linter cases, 7 notes-config cases, 11 decide-hook cases on synthetic transcripts, 1 check that the plugin wires the hook, and 2 checks on SKILL.md.

## 6. Limitations

- No measured learning outcome yet. The recall-check design rests on retrieval-practice research, not on data from this skill.
- The skill depends on the `AskUserQuestion` tool for its checks. Without it, options appear as plain text.
- The quality of a catch-up depends on the sources it can read. A session with no handoff, commits or transcript gives a thin card.
- The decide hook matches English phrasing with fixed patterns. It misses decisions phrased in other ways, and it can fire on a reply that only describes decisions. When it fires by mistake, the agent says so in one line and stops.
- The decide hook reads the Claude Code transcript format. A change to that format can silence the hook; it never blocks on a transcript it cannot read.

## 7. Future work

- Record round trips per walk step across live sessions.
- Define an outcome measure for unstick and catch-up, for example recall accuracy on a later session.
- Measure `extra_turns_to_first_decision` with the decide hook on and off.

## 8. Documentation

- [SKILL.md](skills/sync-me/SKILL.md): the full specification.
- [llms.txt](llms.txt): index for language models.
- [CHANGELOG.md](CHANGELOG.md).

## 9. Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## 10. Reuse

Cite with [CITATION.cff](CITATION.cff) or the concept DOI [10.5281/zenodo.23459402](https://doi.org/10.5281/zenodo.23459402), which covers all released versions.

## 11. License

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
