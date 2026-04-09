#!/usr/bin/env bash
set -euo pipefail

# claude-reset-project.sh — Completely purge all Claude Code state for a project
#
# Usage: bash claude-reset-project.sh [path/to/project]
#        Defaults to current working directory if no path given.
#        Accepts Windows paths: bash claude-reset-project.sh 'C:\Users\Tomas\source\repos\MyProject'
#        Accepts Unix paths:    bash claude-reset-project.sh /c/Users/Tomas/source/repos/MyProject
#
# What it removes:
#   LOCAL (in project dir):
#     .claude/           — project settings, local config
#     .learnings/        — accumulated learnings
#     CLAUDE.md          — project instructions
#     CLAUDE.local.md    — personal project instructions
#     .mcp.json          — MCP server config
#
#   GLOBAL (in ~/.claude/):
#     projects/{encoded}/         — sessions, memory, subagents, tool-results
#     file-history/{session}/     — file version history per session
#     tasks/{session}/            — task state per session
#     session-env/{session}/      — environment snapshots per session
#     todos/{session}-*.json      — todo files per session
#     sessions/*.json             — session metadata (where cwd matches)

# --- Detect CLAUDE_HOME ---
# Claude Code on Windows stores data under the Windows user profile, regardless
# of whether bash is Git Bash, WSL, or MSYS2. Prioritize USERPROFILE over $HOME.
CLAUDE_HOME=""
if [[ -n "${USERPROFILE:-}" ]]; then
    candidate="$(echo "$USERPROFILE" | sed 's|\\|/|g')/.claude"
    [[ -d "$candidate" ]] && CLAUDE_HOME="$candidate"
fi
if [[ -z "$CLAUDE_HOME" ]] && [[ -d "/mnt/c/Users" ]]; then
    win_user="$(cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r')"
    candidate="/mnt/c/Users/${win_user}/.claude"
    [[ -d "$candidate" ]] && CLAUDE_HOME="$candidate"
fi
if [[ -z "$CLAUDE_HOME" ]] && [[ -d "${HOME}/.claude/projects" ]]; then
    CLAUDE_HOME="${HOME}/.claude"
fi
if [[ -z "$CLAUDE_HOME" ]]; then
    echo "ERROR: Cannot find Claude Code data directory"
    echo "  Checked: \${USERPROFILE}/.claude, /mnt/c/Users/.../.claude, \${HOME}/.claude"
    exit 1
fi

# --- Normalize any path to C:/Users/... format (for encoding & display) ---
normalize_to_win() {
    local p="$1"
    p="$(echo "$p" | sed 's|\\|/|g')"
    if [[ "$p" =~ ^/mnt/([a-zA-Z])/(.*) ]]; then
        p="${BASH_REMATCH[1]^^}:/${BASH_REMATCH[2]}"
    elif [[ "$p" =~ ^/([a-zA-Z])/(.*) ]]; then
        p="${BASH_REMATCH[1]^^}:/${BASH_REMATCH[2]}"
    fi
    echo "$p"
}

# --- Convert C:/Users/... to a path the current shell can access ---
to_local_path() {
    local p="$1"
    # Test if the path works as-is (Git Bash can access C:/ paths)
    if [[ -e "$p" ]] || [[ -e "$(dirname "$p")" ]]; then
        echo "$p"
        return
    fi
    # WSL: convert C:/Users/... to /mnt/c/Users/...
    if [[ "$p" =~ ^([A-Za-z]):/(.*) ]]; then
        local drive="${BASH_REMATCH[1],,}"
        echo "/mnt/${drive}/${BASH_REMATCH[2]}"
        return
    fi
    echo "$p"
}

# --- Resolve project path ---
if [[ $# -ge 1 ]]; then
    INPUT_PATH="$1"
else
    CWD="$(normalize_to_win "$(pwd -W 2>/dev/null || pwd)")"
    echo "No path provided."
    echo ""
    read -rp "Enter project path (or press Enter for ${CWD}): " INPUT_PATH
    if [[ -z "$INPUT_PATH" ]]; then
        INPUT_PATH="$CWD"
    fi
fi

# Strip trailing slashes
INPUT_PATH="${INPUT_PATH%/}"
INPUT_PATH="${INPUT_PATH%\\}"

# Normalize to forward-slash Windows path for encoding (C:/Users/...)
PROJECT_WIN="$(normalize_to_win "$INPUT_PATH")"

# Verify it looks like a valid absolute path
if [[ ! "$PROJECT_WIN" =~ ^[A-Za-z]:/ ]]; then
    if [[ -d "$INPUT_PATH" ]]; then
        PROJECT_WIN="$(normalize_to_win "$(cd "$INPUT_PATH" && pwd -W 2>/dev/null || pwd)")"
    else
        echo "ERROR: Cannot resolve path: ${INPUT_PATH}"
        exit 1
    fi
fi

# Local path that the current shell can actually access for file operations
PROJECT_LOCAL="$(to_local_path "$PROJECT_WIN")"

# Backslash version for matching session cwd fields in JSON
WIN_PATH_BS="$(echo "$PROJECT_WIN" | sed 's|/|\\|g')"

echo "============================================"
echo "  Claude Code Project Reset"
echo "============================================"
echo ""
echo "Project:       ${WIN_PATH_BS}"
echo ""

# --- Encode project path to folder name ---
# Convention: any non-alphanumeric, non-dash character becomes a dash
encode_path() {
    local p="$1"
    echo "$p" | sed 's|[^a-zA-Z0-9-]|-|g'
}

ENCODED="$(encode_path "$PROJECT_WIN")"
PROJECT_GLOBAL_DIR="${CLAUDE_HOME}/projects/${ENCODED}"

echo "Global state:  ~/.claude/projects/${ENCODED}"
echo ""

# --- Collect items to delete ---
declare -a TO_DELETE_DIRS=()
declare -a TO_DELETE_FILES=()
declare -a SESSION_UUIDS=()

# Local project files & directories
[[ -d "${PROJECT_LOCAL}/.claude" ]] && TO_DELETE_DIRS+=("${PROJECT_LOCAL}/.claude")
[[ -d "${PROJECT_LOCAL}/.learnings" ]] && TO_DELETE_DIRS+=("${PROJECT_LOCAL}/.learnings")
[[ -f "${PROJECT_LOCAL}/CLAUDE.md" ]] && TO_DELETE_FILES+=("${PROJECT_LOCAL}/CLAUDE.md")
[[ -f "${PROJECT_LOCAL}/CLAUDE.local.md" ]] && TO_DELETE_FILES+=("${PROJECT_LOCAL}/CLAUDE.local.md")
[[ -f "${PROJECT_LOCAL}/.mcp.json" ]] && TO_DELETE_FILES+=("${PROJECT_LOCAL}/.mcp.json")

# Global project directory (sessions, memory, etc.)
if [[ -d "${PROJECT_GLOBAL_DIR}" ]]; then
    for jsonl in "${PROJECT_GLOBAL_DIR}"/*.jsonl; do
        [[ -f "$jsonl" ]] || continue
        uuid="$(basename "$jsonl" .jsonl)"
        SESSION_UUIDS+=("$uuid")
    done
    TO_DELETE_DIRS+=("${PROJECT_GLOBAL_DIR}")
fi

# Session-linked global directories
for uuid in "${SESSION_UUIDS[@]}"; do
    [[ -d "${CLAUDE_HOME}/file-history/${uuid}" ]] && TO_DELETE_DIRS+=("${CLAUDE_HOME}/file-history/${uuid}")
    [[ -d "${CLAUDE_HOME}/tasks/${uuid}" ]] && TO_DELETE_DIRS+=("${CLAUDE_HOME}/tasks/${uuid}")
    [[ -d "${CLAUDE_HOME}/session-env/${uuid}" ]] && TO_DELETE_DIRS+=("${CLAUDE_HOME}/session-env/${uuid}")

    for todo in "${CLAUDE_HOME}/todos/${uuid}-"*.json; do
        [[ -f "$todo" ]] && TO_DELETE_FILES+=("$todo")
    done
done

# Session metadata files (sessions/*.json) — check cwd field
if [[ -d "${CLAUDE_HOME}/sessions" ]]; then
    for sess_file in "${CLAUDE_HOME}/sessions"/*.json; do
        [[ -f "$sess_file" ]] || continue
        if grep -q "\"cwd\":\"${WIN_PATH_BS//\\/\\\\}\"" "$sess_file" 2>/dev/null; then
            TO_DELETE_FILES+=("$sess_file")
        fi
    done
fi

# --- Preview ---
echo "--------------------------------------------"
echo "  Items to delete"
echo "--------------------------------------------"
echo ""

if [[ ${#TO_DELETE_DIRS[@]} -eq 0 && ${#TO_DELETE_FILES[@]} -eq 0 ]]; then
    echo "  Nothing found! Project appears already clean."
    exit 0
fi

# Categorize for summary display
local_dirs=0
local_dir_names=()
global_project_dir=""
file_history_count=0
tasks_count=0
session_env_count=0

for d in "${TO_DELETE_DIRS[@]}"; do
    case "$d" in
        "${PROJECT_LOCAL}"/*)
            local_dirs=$((local_dirs + 1))
            local_dir_names+=("$(basename "$d")/")
            ;;
        *"/projects/"*) global_project_dir="$d" ;;
        *"/file-history/"*) file_history_count=$((file_history_count + 1)) ;;
        *"/tasks/"*) tasks_count=$((tasks_count + 1)) ;;
        *"/session-env/"*) session_env_count=$((session_env_count + 1)) ;;
    esac
done

echo "LOCAL (project directory):"
for dname in "${local_dir_names[@]+"${local_dir_names[@]}"}"; do
    local_full="${PROJECT_LOCAL}/${dname%/}"
    size="$(du -sh "$local_full" 2>/dev/null | cut -f1 || echo "?")"
    echo "  [${size}]  ${dname}"
done
for f in "${TO_DELETE_FILES[@]}"; do
    case "$f" in
        "${PROJECT_LOCAL}"/*) echo "  $(basename "$f")" ;;
    esac
done
echo ""

echo "GLOBAL (~/.claude/):"
if [[ -n "$global_project_dir" ]]; then
    size="$(du -sh "$global_project_dir" 2>/dev/null | cut -f1 || echo "?")"
    echo "  [${size}]  projects/${ENCODED}/"
    echo "            (includes ${#SESSION_UUIDS[@]} sessions + memory)"
fi
[[ $file_history_count -gt 0 ]] && echo "  file-history/  — ${file_history_count} session dirs"
[[ $tasks_count -gt 0 ]] && echo "  tasks/         — ${tasks_count} session dirs"
[[ $session_env_count -gt 0 ]] && echo "  session-env/   — ${session_env_count} session dirs"

todo_count=0
for f in "${TO_DELETE_FILES[@]}"; do
    case "$f" in *"/todos/"*) todo_count=$((todo_count + 1)) ;; esac
done
[[ $todo_count -gt 0 ]] && echo "  todos/         — ${todo_count} files"

sess_meta_count=0
for f in "${TO_DELETE_FILES[@]}"; do
    case "$f" in *"/sessions/"*) sess_meta_count=$((sess_meta_count + 1)) ;; esac
done
[[ $sess_meta_count -gt 0 ]] && echo "  sessions/      — ${sess_meta_count} metadata files"

echo ""
echo "Total: ${#TO_DELETE_DIRS[@]} directories, ${#TO_DELETE_FILES[@]} files"
echo ""
echo "--------------------------------------------"
echo ""

# --- Confirm ---
read -rp "Proceed with deletion? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted. Nothing was deleted."
    exit 0
fi

echo ""
echo "Deleting..."

for d in "${TO_DELETE_DIRS[@]}"; do
    rm -rf "$d"
    echo "  Deleted: ${d}"
done

for f in "${TO_DELETE_FILES[@]}"; do
    rm -f "$f"
    echo "  Deleted: ${f}"
done

echo ""
echo "Done. All Claude Code state for this project has been removed."
echo ""
echo "Note: The global history.jsonl and plans/ may still contain"
echo "references to this project. These are shared across all projects"
echo "and cannot be selectively cleaned without parsing content."
