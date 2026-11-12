#!/usr/bin/env bash
# Optional Claude Code Stop hook for sync-me decide mode.
#
# When the agent ends its turn with decisions for the user written as prose,
# and that turn made no AskUserQuestion call, this hook blocks the stop once
# and tells the agent to run decide mode.
#
# Off by default. It acts only when the user turned it on:
#   SYNC_ME_DECIDE_HOOK=on|off in the environment (wins over the config), or
#   a line decide_hook=on in the sync-me config:
#     1. <repo>/.sync-me/config
#     2. ${SYNC_ME_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/sync-me/config}
#   The first file with a decide_hook line wins. Set it with
#   notes_path.sh --hook on|off [--user].
#
# Input: the Stop hook JSON on stdin (transcript_path, stop_hook_active, cwd).
# Output: nothing, or {"decision": "block", "reason": "..."} on stdout.
# Always exits 0. Writes no files. Needs jq; without jq it does nothing.
#
# Silent when: disabled, stop_hook_active is true (never loops),
# AGENTS_INC_WORKER is set, jq is missing, or the transcript is missing or
# unreadable.

# Lines that open a decision list: the label starts the line (after list or
# heading markup) and ends with a colon, a question mark or the line end.
LABEL_RE='^\s*(?:[-*+]\s+|\d+[.)]\s+)?(?:#{1,6}\s+)?(?:\*\*|__)?\s*(?:your\s+(?:calls?|decisions?|rulings?|pick)|decide|(?:decisions?|rulings?|calls?)\s+(?:for\s+you|needed|pending|waiting(?:\s+on\s+you)?|you\s+need\s+to\s+make|only\s+you\s+can\s+make)|(?:open|pending)\s+decisions|needs?\s+your\s+(?:decision|call|ruling|sign-?off|approval|input)|(?:open\s+)?questions?\s+for\s+you|what\s+you\s+need\s+to\s+(?:decide|choose)|what\s+i\s+need\s+from\s+you|to\s+decide)\s*(?:\*\*|__)?\s*(?::|\?|$)'

# Phrases that ask the user for a decision anywhere in a line.
PHRASE_RE='\bi\s+need\s+(?:(?:one|two|three|four|five|six|\d+|a\s+few|several|some)\s+)?(?:decisions?|rulings?|calls?|answers?|sign-?offs?)\s+from\s+you\b|\bi\s+need\s+(?:one|two|three|four|five|six|\d+|a\s+few|several)\s+(?:decisions?|rulings?|calls?)\b|\bi\s+need\s+(?:a|your)\s+(?:decision|ruling|call|sign-?off|go-?ahead)\b|\b(?:still\s+)?waiting\s+on\s+(?:you\b|your\s+(?:decision|call|answer|ruling|input|sign-?off|go-?ahead))|\b(?:need|needs|waiting\s+for)\s+your\s+(?:decision|ruling|call|sign-?off)\b|\b(?:rulings?|decisions?|calls?)\s+only\s+you\s+can\s+make\b|\bonly\s+you\s+can\s+(?:decide|choose|rule|pick|approve)\b|\buntil\s+you\s+(?:rule|decide|choose|pick|approve|sign\s+off|confirm|say\s+which)\b|\bdecisions?\s+(?:for|from)\s+you\b|\bwhich\s+(?:one\s+|option\s+|way\s+|path\s+)?(?:do\s+you\s+(?:want|prefer)|would\s+you\s+(?:like|prefer|pick|choose))\b[^?]*\?'

# A list item that ends with a question mark. Two or more of them fire.
QITEM_RE='^\s*(?:[-*+]\s+|\d+[.)]\s+).*\?\s*(?:\*\*|__)?\s*$'

REASON='sync-me decide hook: your last reply leaves decisions for the user in prose, and this turn made no AskUserQuestion call. Before you stop, run the sync-me skill in decide mode. List each pending decision. If several hang on one that was never stated, ask that one first. Ask each decision through AskUserQuestion, one per call, recommended option first, with what happens next and what each option costs. If the reply holds no decision for the user, say so in one line and stop.'

config_value() {
    # Print the decide_hook value from the first config file that has one.
    local repo="$1" user_cfg f v
    user_cfg="${SYNC_ME_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/sync-me/config}"
    for f in "$repo/.sync-me/config" "$user_cfg"; do
        if [[ -r "$f" ]]; then
            v="$(sed -n 's/^decide_hook=//p' "$f" 2>/dev/null | head -1 | tr -d '[:space:]')"
            if [[ -n "$v" ]]; then printf '%s\n' "$v"; return 0; fi
        fi
    done
    return 1
}

main() {
    [[ -z "${AGENTS_INC_WORKER:-}" ]] || return 0
    [[ "${SYNC_ME_DECIDE_HOOK:-}" != "off" ]] || return 0
    command -v jq > /dev/null 2>&1 || return 0

    local input active transcript cwd repo enabled text
    input="$(cat)"
    active="$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)"
    [[ "$active" == "false" ]] || return 0

    if [[ "${SYNC_ME_DECIDE_HOOK:-}" == "on" ]]; then
        enabled="on"
    else
        cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
        [[ -n "$cwd" && -d "$cwd" ]] || cwd="$PWD"
        repo="${SYNC_ME_REPO:-$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")}"
        enabled="$(config_value "$repo" || true)"
    fi
    [[ "$enabled" == "on" ]] || return 0

    transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
    [[ -n "$transcript" && -f "$transcript" && -r "$transcript" ]] || return 0

    # The last turn: assistant entries after the last user entry that carries
    # text (tool results do not start a turn). If any of them called
    # AskUserQuestion, print nothing. Otherwise print the closing reply: the
    # text blocks after the turn's last tool call.
    text="$(tail -n 400 "$transcript" 2>/dev/null | jq -R -n -r '
        [inputs | fromjson? | select(type == "object")] as $e
        | ([$e | to_entries[]
            | select(.value.type == "user"
                and ((.value.message.content | type) == "string"
                     or ([.value.message.content[]? | select(type == "object" and .type == "text")] | length > 0)))
            | .key] | last // -1) as $start
        | [$e[($start + 1):][] | select(.type == "assistant") | .message.content[]? | select(type == "object")] as $b
        | if ([$b[] | select(.type == "tool_use" and .name == "AskUserQuestion")] | length) > 0 then ""
          else
            ([$b | to_entries[] | select(.value.type == "tool_use") | .key] | last // -1) as $lt
            | [$b[($lt + 1):][] | select(.type == "text") | .text] | join("\n")
          end
    ' 2>/dev/null)" || return 0
    [[ -n "$text" ]] || return 0

    # Drop what the agent quotes rather than says: fenced code, block quotes,
    # inline code and short double-quoted spans. Then match line by line.
    printf '%s' "$text" | jq -R -s -e --arg label "$LABEL_RE" --arg phrase "$PHRASE_RE" --arg qitem "$QITEM_RE" '
        split("\n")
        | reduce .[] as $l ({fence: false, out: []};
            if ($l | test("^\\s*(```|~~~)")) then .fence = (.fence | not)
            elif .fence or ($l | test("^\\s*>")) then .
            else .out += [$l | gsub("`[^`]*`"; "") | gsub("\"[^\"]{0,120}\""; "") | gsub("“[^”]{0,120}”"; "")]
            end)
        | .out
        | (map(select(test($label; "i") or test($phrase; "i"))) | length > 0)
          or (map(select(test($qitem; "i"))) | length >= 2)
    ' > /dev/null 2>&1 || return 0

    jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
}

main "$@" 2>/dev/null || true
exit 0
