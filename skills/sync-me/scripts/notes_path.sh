#!/usr/bin/env bash
# Resolve or set where sync-me writes its notes.
#
# Usage:
#   notes_path.sh                 print the notes dir for the current repo
#   notes_path.sh --set local     save notes in <repo>/.sync-me/ (the default choice)
#   notes_path.sh --set <path>    save notes in <path>/<repo>/ (a central store)
#   notes_path.sh --root          print the notes root (where NOTES.md lives)
#
# Config lookup order (first hit wins):
#   1. <repo>/.sync-me/config
#   2. ${SYNC_ME_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/sync-me/config}
# Config format: one line, notes_root=local | notes_root=<absolute path>
# --set writes the per-repo config (1).
#
# Exit codes: 0 ok; 2 usage error; 4 no config yet (ask the user, then --set).
set -euo pipefail

REPO_DIR="${SYNC_ME_REPO:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
REPO_NAME="$(basename "$REPO_DIR")"
LOCAL_CFG="$REPO_DIR/.sync-me/config"
USER_CFG="${SYNC_ME_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/sync-me/config}"

read_root() {
    local f
    for f in "$LOCAL_CFG" "$USER_CFG"; do
        if [[ -f "$f" ]]; then
            local v
            v="$(sed -n 's/^notes_root=//p' "$f" | head -1)"
            if [[ -n "$v" ]]; then printf '%s\n' "$v"; return 0; fi
        fi
    done
    return 1
}

case "${1:-}" in
    --set)
        [[ $# -eq 2 && -n "$2" ]] || { echo "usage: --set local|<absolute path>" >&2; exit 2; }
        val="$2"
        if [[ "$val" != "local" && "$val" != /* ]]; then
            echo "ERROR: central path must be absolute: $val" >&2; exit 2
        fi
        mkdir -p "$REPO_DIR/.sync-me"
        printf 'notes_root=%s\n' "$val" > "$LOCAL_CFG"
        echo "saved: $LOCAL_CFG"
        ;;
    ""|--root)
        if ! root="$(read_root)"; then
            echo "NO_CONFIG: ask the user where to save notes, then run --set" >&2
            exit 4
        fi
        if [[ "$root" == "local" ]]; then
            base="$REPO_DIR/.sync-me"; dir="$base"
        else
            base="$root"; dir="$root/$REPO_NAME"
        fi
        if [[ "${1:-}" == "--root" ]]; then echo "$base"; else echo "$dir"; fi
        ;;
    *)
        echo "usage: $(basename "$0") [--root | --set local|<path>]" >&2; exit 2 ;;
esac
