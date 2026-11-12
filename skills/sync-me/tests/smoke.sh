#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="${HERE}/../scripts/validate_runbook.sh"
NOTES="${HERE}/../scripts/notes_path.sh"
SKILL_MD="${HERE}/../SKILL.md"

PASS=0
FAIL=0

check() {
    if [[ "$3" -eq "$2" ]]; then
        echo "[PASS] $1"; PASS=$((PASS+1))
    else
        echo "[FAIL] $1 (expected $2 got $3)"; FAIL=$((FAIL+1))
    fi
}

# --- walk-mode runbook linter ---
"$SCRIPT" "${HERE}/fixtures/valid_runbook.json" > /dev/null 2>&1
check "valid_runbook.json" 0 "$?"
"$SCRIPT" "${HERE}/fixtures/invalid_schema.json" > /dev/null 2>&1
check "invalid_schema.json" 1 "$?"

# Fake token assembled at runtime so no secret-shaped literal is committed.
SECRET_FIXTURE="$(mktemp "${TMPDIR:-/tmp}/sync-me-smoke.XXXXXX")"
FAKE_KEY="sk-ant-""api03-$(printf 'A%.0s' {1..40})"
cat > "$SECRET_FIXTURE" <<JSON
{"title": "Broken runbook", "steps": [{"id": 1, "title": "Paste key",
 "instruction": "Use this token: ${FAKE_KEY} in the Client Secret field.",
 "success": {"label": "OK", "assert": "field shows a saved value"},
 "failures": [{"label": "Rejected", "diagnosis_hint": "trailing whitespace"}]}]}
JSON
"$SCRIPT" "$SECRET_FIXTURE" > /dev/null 2>&1
check "runtime secret fixture" 3 "$?"
rm -f "$SECRET_FIXTURE"

"$SCRIPT" "${HERE}/fixtures/does_not_exist.json" > /dev/null 2>&1
check "missing file" 2 "$?"
"$SCRIPT" > /dev/null 2>&1
check "no arguments" 2 "$?"

# --- notes location config ---
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/sync-me-notes.XXXXXX")"
mkdir -p "$SANDBOX/myrepo"
export SYNC_ME_REPO="$SANDBOX/myrepo" SYNC_ME_CONFIG="$SANDBOX/user-config"

"$NOTES" > /dev/null 2>&1
check "no config yet asks the user (exit 4)" 4 "$?"

"$NOTES" --set relative/path > /dev/null 2>&1
check "relative central path refused" 2 "$?"

"$NOTES" --set local > /dev/null 2>&1
out="$("$NOTES" 2>/dev/null)"
[[ "$out" == "$SANDBOX/myrepo/.sync-me" ]]; check "local choice resolves to <repo>/.sync-me" 0 "$?"

"$NOTES" --set "$SANDBOX/central" > /dev/null 2>&1
out="$("$NOTES" 2>/dev/null)"; root="$("$NOTES" --root 2>/dev/null)"
[[ "$out" == "$SANDBOX/central/myrepo" && "$root" == "$SANDBOX/central" ]]
check "central choice resolves to <path>/<repo>" 0 "$?"

rm -f "$SANDBOX/myrepo/.sync-me/config"
echo "notes_root=$SANDBOX/userwide" > "$SANDBOX/user-config"
out="$("$NOTES" 2>/dev/null)"
[[ "$out" == "$SANDBOX/userwide/myrepo" ]]; check "user-level config is the fallback" 0 "$?"

"$NOTES" --hook on > /dev/null 2>&1 && "$NOTES" --set local > /dev/null 2>&1
grep -qx 'decide_hook=on' "$SANDBOX/myrepo/.sync-me/config" \
    && grep -qx 'notes_root=local' "$SANDBOX/myrepo/.sync-me/config"
check "--hook and --set keep each other's line" 0 "$?"

"$NOTES" --hook maybe > /dev/null 2>&1
check "--hook refuses a value other than on or off" 2 "$?"
rm -rf "$SANDBOX"
unset SYNC_ME_REPO SYNC_ME_CONFIG

# --- decide Stop hook (synthetic transcripts) ---
HOOK="${HERE}/../scripts/decide_stop_hook.sh"
HSB="$(mktemp -d "${TMPDIR:-/tmp}/sync-me-hook.XXXXXX")"
mkdir -p "$HSB/repo"
unset AGENTS_INC_WORKER SYNC_ME_DECIDE_HOOK
export SYNC_ME_REPO="$HSB/repo" SYNC_ME_CONFIG="$HSB/user-config"

user_msg() { jq -cn --arg t "$1" '{type: "user", message: {role: "user", content: $t}}'; }
tool_call() { jq -cn --arg n "$1" '{type: "assistant", message: {role: "assistant", content: [{type: "tool_use", id: "t1", name: $n, input: {}}]}}'; }
tool_result() { jq -cn '{type: "user", message: {role: "user", content: [{type: "tool_result", tool_use_id: "t1", content: "ok"}]}}'; }
reply() { jq -cn --arg t "$1" '{type: "assistant", message: {role: "assistant", content: [{type: "text", text: $t}]}}'; }

DECISIONS=$'The build is green and the migration ran on the staging copy.\n\n**Your calls:**\n1. Keep the old endpoint for one more release, or remove it now.\n2. Ship on Friday, or wait for the load test.'
{ user_msg "Status?"; tool_call Bash; tool_result; reply "$DECISIONS"; } > "$HSB/decisions.jsonl"
{ user_msg "Status?"; reply "Tests pass. I need three decisions from you before I merge, listed in the plan file."; } > "$HSB/phrase.jsonl"
{ user_msg "Status?"; tool_call Bash; tool_result; reply "The build is green. All 41 tests pass and the changelog is updated. Next I will tag the draft. Want me to open a pull request?"; } > "$HSB/status.jsonl"
{ user_msg "How does the hook work?"; reply 'It fires on a line such as `Your calls:` when no question was asked.'; } > "$HSB/mention.jsonl"
{ user_msg "Status?"; tool_call AskUserQuestion; tool_result; reply "$DECISIONS"; } > "$HSB/asked.jsonl"

run_hook() {  # <transcript> [stop_hook_active]
    printf '{"transcript_path": "%s", "stop_hook_active": %s, "cwd": "%s"}' "$1" "${2:-false}" "$HSB/repo" | bash "$HOOK"
}
hook_fires() { local o; o="$(run_hook "$@")" && [[ "$o" == *'"decision": "block"'* ]]; }
hook_silent() { local o; o="$(run_hook "$@")" && [[ -z "$o" ]]; }

hook_silent "$HSB/decisions.jsonl"; check "hook is off by default (no config line)" 0 "$?"
echo "decide_hook=on" > "$HSB/user-config"
hook_fires "$HSB/decisions.jsonl"; check "hook fires on a decision list" 0 "$?"
hook_fires "$HSB/phrase.jsonl"; check "hook fires on 'I need three decisions from you'" 0 "$?"
hook_silent "$HSB/status.jsonl"; check "hook silent on a plain status report" 0 "$?"
hook_silent "$HSB/mention.jsonl"; check "hook silent when the phrase is only quoted as code" 0 "$?"
hook_silent "$HSB/asked.jsonl"; check "hook silent when the turn used AskUserQuestion" 0 "$?"
hook_silent "$HSB/decisions.jsonl" true; check "hook silent when stop_hook_active is true" 0 "$?"
hook_silent "$HSB/missing.jsonl"; check "hook silent on a missing transcript" 0 "$?"
SYNC_ME_DECIDE_HOOK=off hook_silent "$HSB/decisions.jsonl"; check "hook silent when SYNC_ME_DECIDE_HOOK=off" 0 "$?"
AGENTS_INC_WORKER=1 hook_silent "$HSB/decisions.jsonl"; check "hook silent when AGENTS_INC_WORKER is set" 0 "$?"
mkdir -p "$HSB/repo/.sync-me" && echo "decide_hook=off" > "$HSB/repo/.sync-me/config"
hook_silent "$HSB/decisions.jsonl"; check "repo config decide_hook=off overrides the user config" 0 "$?"
rm -rf "$HSB"
unset SYNC_ME_REPO SYNC_ME_CONFIG

PLUGIN_ROOT="${HERE}/../../../plugins/sync-me"
cmd="$(jq -r '.hooks.Stop[0].hooks[0].command' "$PLUGIN_ROOT/hooks/hooks.json" 2>/dev/null)"
path="${cmd#bash \"\$\{CLAUDE_PLUGIN_ROOT\}/}"; path="${path%\"}"
[[ "$cmd" == *decide_stop_hook.sh* && -f "$PLUGIN_ROOT/$path" ]]
check "plugin hooks.json points at the hook script" 0 "$?"

# --- SKILL.md contract ---
contract_ok=0
for pat in '^name: sync-me$' '^## Unstick mode' '^## Catch-up mode' '^## Walk mode' \
           '^## Decide mode' 'Explain this first' '\(Recommended\)' 'decide_stop_hook.sh' \
           '^## Where notes go' 'legacy alias: explain' 'Card first' 'teach me' \
           'machine-teaching' 'notes_path.sh'; do
    if ! grep -qE "$pat" "$SKILL_MD"; then
        echo "       missing in SKILL.md: $pat"; contract_ok=1
    fi
done
check "SKILL.md contract" 0 "$contract_ok"

dep_ok=0
if grep -nE 'DomI|asd-ste100-lens|write-like-scientist|agent-doc-sweep|doc_provenance|\.teach-me|—' "$SKILL_MD"; then
    dep_ok=1
fi
check "SKILL.md has no external skill deps or em-dashes" 0 "$dep_ok"

echo "---"
echo "sync-me smoke: ${PASS} pass, ${FAIL} fail"
[[ "$FAIL" -eq 0 ]] || exit 1
