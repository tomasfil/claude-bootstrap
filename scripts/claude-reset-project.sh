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
#     CLAUDE.md          — project instructions (optional)
#     CLAUDE.local.md    — personal project instructions (optional)
#     .mcp.json          — MCP server config (optional)
#
#   GLOBAL (in ~/.claude/):
#     projects/{encoded}/         — sessions, memory, subagents, tool-results
#     file-history/{session}/     — file version history per session
#     tasks/{session}/            — task state per session
#     session-env/{session}/      — environment snapshots per session
#     todos/{session}-*.json      — todo files per session
#     sessions/*.json             — session metadata (where cwd matches)

CLAUDE_HOME="${HOME}/.claude"

# --- Resolve project path ---
if [[ $# -ge 1 ]]; then
    INPUT_PATH="$1"
else
    CWD="$(pwd -W 2>/dev/null || pwd)"
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

# Normalize: accept Windows paths (C:\foo), Unix paths (/c/foo), or relative paths
if [[ "$INPUT_PATH" =~ ^[A-Za-z]:[/\\] ]]; then
    # Already an absolute Windows-style path — normalize slashes to forward
    PROJECT_PATH="$(echo "$INPUT_PATH" | sed 's|\\|/|g')"
elif [[ "$INPUT_PATH" =~ ^/([a-zA-Z])/ ]]; then
    # Unix-style /c/Users/... → C:/Users/...
    drive="${BASH_REMATCH[1]}"
    PROJECT_PATH="${drive^^}:${INPUT_PATH:2}"
elif [[ -d "$INPUT_PATH" ]]; then
    # Relative path — resolve it
    PROJECT_PATH="$(cd "$INPUT_PATH" && pwd -W 2>/dev/null || pwd)"
else
    echo "ERROR: Path does not exist: ${INPUT_PATH}"
    exit 1
fi

# Ensure forward slashes for internal use
PROJECT_PATH="$(echo "$PROJECT_PATH" | sed 's|\\|/|g')"
# Backslash version for matching session cwd fields
WIN_PATH_BS="$(echo "$PROJECT_PATH" | sed 's|/|\\|g')"

echo "============================================"
echo "  Claude Code Project Reset"
echo "============================================"
echo ""
echo "Project:       ${WIN_PATH_BS}"
echo ""

# --- Encode project path to folder name ---
# Convention: each : / \ becomes a single dash
# C:\Users\Tomas\source\repos\foo → C--Users-Tomas-source-repos-foo
# (C: → C- and \ → - so C:\ produces C--)
encode_path() {
    local p="$1"
    # Replace every : / \ with a single dash
    echo "$p" | sed 's|[:/\\]|-|g'
}

ENCODED="$(encode_path "$PROJECT_PATH")"
PROJECT_GLOBAL_DIR="${CLAUDE_HOME}/projects/${ENCODED}"

echo "Global state:  ~/.claude/projects/${ENCODED}"
echo ""

# --- Collect items to delete ---
declare -a TO_DELETE_DIRS=()
declare -a TO_DELETE_FILES=()
declare -a SESSION_UUIDS=()

# Local project files
[[ -d "${PROJECT_PATH}/.claude" ]] && TO_DELETE_DIRS+=("${PROJECT_PATH}/.claude")
[[ -f "${PROJECT_PATH}/CLAUDE.md" ]] && TO_DELETE_FILES+=("${PROJECT_PATH}/CLAUDE.md")
[[ -f "${PROJECT_PATH}/CLAUDE.local.md" ]] && TO_DELETE_FILES+=("${PROJECT_PATH}/CLAUDE.local.md")
[[ -f "${PROJECT_PATH}/.mcp.json" ]] && TO_DELETE_FILES+=("${PROJECT_PATH}/.mcp.json")

# Global project directory (sessions, memory, etc.)
if [[ -d "${PROJECT_GLOBAL_DIR}" ]]; then
    # Extract session UUIDs from .jsonl filenames
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

    # Todos: {session-uuid}-agent-*.json
    for todo in "${CLAUDE_HOME}/todos/${uuid}-"*.json; do
        [[ -f "$todo" ]] && TO_DELETE_FILES+=("$todo")
    done
done

# Session metadata files (sessions/*.json) — check cwd field
if [[ -d "${CLAUDE_HOME}/sessions" ]]; then
    for sess_file in "${CLAUDE_HOME}/sessions"/*.json; do
        [[ -f "$sess_file" ]] || continue
        # Check if cwd matches our project path
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

# Categorize directories for summary display
local_dirs=0
global_project_dir=""
file_history_count=0
tasks_count=0
session_env_count=0
other_dirs=()

for d in "${TO_DELETE_DIRS[@]}"; do
    case "$d" in
        "${PROJECT_PATH}"/*) local_dirs=$((local_dirs + 1)) ;;
        *"/projects/"*) global_project_dir="$d" ;;
        *"/file-history/"*) file_history_count=$((file_history_count + 1)) ;;
        *"/tasks/"*) tasks_count=$((tasks_count + 1)) ;;
        *"/session-env/"*) session_env_count=$((session_env_count + 1)) ;;
        *) other_dirs+=("$d") ;;
    esac
done

echo "LOCAL (project directory):"
if [[ -d "${PROJECT_PATH}/.claude" ]]; then
    size="$(du -sh "${PROJECT_PATH}/.claude" 2>/dev/null | cut -f1 || echo "?")"
    echo "  [${size}]  .claude/"
fi
for f in "${TO_DELETE_FILES[@]}"; do
    case "$f" in
        "${PROJECT_PATH}"/*) echo "  $(basename "$f")" ;;
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

# Count todo files for this project
todo_count=0
for f in "${TO_DELETE_FILES[@]}"; do
    case "$f" in
        *"/todos/"*) todo_count=$((todo_count + 1)) ;;
    esac
done
[[ $todo_count -gt 0 ]] && echo "  todos/         — ${todo_count} files"

# Count session metadata files
sess_meta_count=0
for f in "${TO_DELETE_FILES[@]}"; do
    case "$f" in
        *"/sessions/"*) sess_meta_count=$((sess_meta_count + 1)) ;;
    esac
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

# Delete directories
for d in "${TO_DELETE_DIRS[@]}"; do
    rm -rf "$d"
    echo "  Deleted: ${d}"
done

# Delete files
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
