#!/usr/bin/env bash
set -uo pipefail

# Validate a sync-me walk-mode runbook JSON file against schema and secret hygiene rules.

usage() {
    echo "Usage: $(basename "$0") <path-to-runbook.json>" >&2
    exit 2
}

if [[ $# -eq 0 ]]; then
    usage
fi

RUNBOOK="$1"

# Check file exists
if [[ ! -f "$RUNBOOK" ]]; then
    echo "ERROR: File does not exist: $RUNBOOK" >&2
    exit 2
fi

# Check jq available
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq required" >&2
    exit 2
fi

# Check valid JSON
if ! jq empty "$RUNBOOK" 2>/dev/null; then
    echo "ERROR: Not valid JSON: $RUNBOOK" >&2
    exit 2
fi

# ============================================================================
# Schema validation
# ============================================================================

SCHEMA_ERRORS=0

# Check .steps exists and is non-empty array
if ! jq -e '.steps | type == "array" and length > 0' "$RUNBOOK" &>/dev/null; then
    echo "SCHEMA: Top-level .steps must exist and be a non-empty array" >&2
    ((SCHEMA_ERRORS++))
fi

# Check each step and collect all violations
STEP_COUNT=$(jq '.steps | length' "$RUNBOOK")
SEEN_IDS=()
for ((i=0; i<STEP_COUNT; i++)); do
    STEP=$(jq ".steps[$i]" "$RUNBOOK")

    # Check .id exists and is a number
    if ! jq -e '.id | type == "number"' <<< "$STEP" &>/dev/null; then
        echo "SCHEMA: Step $i: .id must be a number" >&2
        ((SCHEMA_ERRORS++))
    else
        ID=$(jq '.id' <<< "$STEP")
        # Check for duplicate IDs
        found_dup=0
        for seen_id in "${SEEN_IDS[@]:-}"; do
          if [[ "$seen_id" == "$ID" ]]; then
            found_dup=1
            break
          fi
        done
        if [[ $found_dup -eq 1 ]]; then
            echo "SCHEMA: Duplicate .id value: $ID" >&2
            ((SCHEMA_ERRORS++))
        fi
        SEEN_IDS+=("$ID")
    fi

    # Check .title exists and is non-empty string
    if ! jq -e '.title | type == "string" and length > 0' <<< "$STEP" &>/dev/null; then
        echo "SCHEMA: Step $i: .title must be a non-empty string" >&2
        ((SCHEMA_ERRORS++))
    fi

    # Check .instruction exists and is non-empty string
    if ! jq -e '.instruction | type == "string" and length > 0' <<< "$STEP" &>/dev/null; then
        echo "SCHEMA: Step $i: .instruction must be a non-empty string" >&2
        ((SCHEMA_ERRORS++))
    fi

    # Check .success object
    if ! jq -e '.success | type == "object"' <<< "$STEP" &>/dev/null; then
        echo "SCHEMA: Step $i: .success must be an object" >&2
        ((SCHEMA_ERRORS++))
    else
        if ! jq -e '.success.label | type == "string" and length > 0' <<< "$STEP" &>/dev/null; then
            echo "SCHEMA: Step $i: .success.label must be a non-empty string" >&2
            ((SCHEMA_ERRORS++))
        fi
        if ! jq -e '.success.assert | type == "string" and length > 0' <<< "$STEP" &>/dev/null; then
            echo "SCHEMA: Step $i: .success.assert must be a non-empty string" >&2
            ((SCHEMA_ERRORS++))
        fi
    fi

    # Check .failures is an array with at least 1 element
    if ! jq -e '.failures | type == "array" and length > 0' <<< "$STEP" &>/dev/null; then
        echo "SCHEMA: Step $i: .failures must be an array with at least 1 element" >&2
        ((SCHEMA_ERRORS++))
    else
        # Check each failure
        FAIL_COUNT=$(jq '.failures | length' <<< "$STEP")
        for ((j=0; j<FAIL_COUNT; j++)); do
            FAILURE=$(jq ".failures[$j]" <<< "$STEP")
            if ! jq -e '.label | type == "string" and length > 0' <<< "$FAILURE" &>/dev/null; then
                echo "SCHEMA: Step $i, failure $j: .label must be a non-empty string" >&2
                ((SCHEMA_ERRORS++))
            fi
            if ! jq -e '.diagnosis_hint | type == "string" and length > 0' <<< "$FAILURE" &>/dev/null; then
                echo "SCHEMA: Step $i, failure $j: .diagnosis_hint must be a non-empty string" >&2
                ((SCHEMA_ERRORS++))
            fi
        done
    fi

    # Check order_critical logic
    if jq -e '.order_critical == true' <<< "$STEP" &>/dev/null; then
        if ! jq -e '.order_note | type == "string" and length > 0' <<< "$STEP" &>/dev/null; then
            echo "SCHEMA: Step $i: .order_critical == true requires non-empty .order_note" >&2
            ((SCHEMA_ERRORS++))
        fi
    fi
done

# ============================================================================
# Secret hygiene check
# ============================================================================

SECRET_ERRORS=0

# Concatenate all step text fields
TEXT_BLOB=$(jq -r '
  .steps[] | (
    (.instruction // ""),
    (.success.label // ""),
    (.success.assert // ""),
    (.failures[] | .label // ""),
    (.failures[] | .diagnosis_hint // "")
  )
' "$RUNBOOK" | tr '\n' ' ')

# Secret patterns (case-sensitive where applicable)
declare -a SECRET_PATTERNS=(
    # Anthropic API key
    'sk-ant-api[0-9]{2}-[A-Za-z0-9_-]{20,}'
    # OpenAI-style API key
    'sk-[A-Za-z0-9]{32,}'
    # GitHub PAT
    'ghp_[A-Za-z0-9]{30,}'
    # AWS access key id
    'AKIA[0-9A-Z]{16}'
)

declare -a MATCHED_PATTERNS=()

for pattern in "${SECRET_PATTERNS[@]}"; do
    if grep -qE "$pattern" <<< "$TEXT_BLOB"; then
        MATCHED_PATTERNS+=("$pattern")
    fi
done

if [[ ${#MATCHED_PATTERNS[@]} -gt 0 ]]; then
    for pattern in "${MATCHED_PATTERNS[@]}"; do
        echo "SECRET: pattern $pattern detected in step text — the AI must never emit a real secret; tell the human to generate it locally instead (openssl rand, etc.)" >&2
    done
    SECRET_ERRORS=1
fi

# ============================================================================
# Final verdict
# ============================================================================

if [[ $SECRET_ERRORS -gt 0 ]]; then
    echo "BLOCKED (secret detected)"
    exit 3
elif [[ $SCHEMA_ERRORS -gt 0 ]]; then
    echo "INVALID (schema)"
    exit 1
else
    echo "VALID"
    exit 0
fi
