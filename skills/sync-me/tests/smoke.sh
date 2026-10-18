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
rm -rf "$SANDBOX"
unset SYNC_ME_REPO SYNC_ME_CONFIG

# --- SKILL.md contract ---
contract_ok=0
for pat in '^name: sync-me$' '^## Unstick mode' '^## Catch-up mode' '^## Walk mode' \
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
