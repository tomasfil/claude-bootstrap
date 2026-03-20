# Hook Reference

## Hook Event Lifecycle

Events fire in this order during a typical session:

1. **SessionStart** — Session begins (startup, resume, clear, or compact)
2. **InstructionsLoaded** (v2.1.69+) — After all instructions are loaded
3. **Notification** — External notification received
4. **UserPromptSubmit** — User sends a message
5. **PermissionRequest** — Before showing a permission prompt
6. **PreToolUse** — Before a tool executes
7. **PostToolUse** — After a tool executes successfully
8. **PostToolUseFailure** — After a tool execution fails
9. **PreCompact** — Before context compaction
10. **SubagentStart** — Subagent spawned
11. **SubagentStop** — Subagent finished
12. **TaskCompleted** — A defined task finishes
13. **ConfigChange** — Settings or config modified
14. **WorktreeCreate** — Git worktree created
15. **WorktreeRemove** — Git worktree removed
16. **Stop** — Agent about to stop
17. **SessionEnd** — Session fully terminates

Additional events:
- **Setup** — First-time project setup
- **TeammateIdle** — Teammate agent has gone idle

## Exit Codes

| Code | Meaning | Behavior |
|------|---------|----------|
| 0 | Success / proceed | Action continues normally |
| 1 | Non-blocking error | Action proceeds; stderr logged in verbose mode only |
| 2 | Block | Action is blocked; stderr displayed as an error to the user |

## Hook Types

### command
Runs a shell command. Receives JSON on stdin. Stdout/stderr handling depends
on exit code.

### prompt
Single-turn model evaluation. A lightweight LLM call without tool access.
Good for classification or simple decision-making.

### http
Sends a POST request with JSON payload to an endpoint. Useful for external
integrations, logging, or webhook-based workflows.

### agent
Spawns a subagent with full tool access. Use for complex hook logic that
requires reading files, running commands, or multi-step reasoning.

## Stdin JSON Payload

Every hook receives a base JSON payload on stdin:

```json
{
  "session_id": "string",
  "transcript_path": "string",
  "cwd": "string",
  "permission_mode": "string",
  "hook_event_name": "string"
}
```

### Event-Specific Fields

**PreToolUse** adds:
- `tool_name` — Name of the tool about to execute
- `tool_input` — The input arguments for the tool
- `tool_use_id` — Unique identifier for this tool invocation

**PostToolUse** adds:
- `tool_name` — Name of the tool that executed
- `tool_input` — The input arguments that were used
- `tool_response` — The tool's response (note: NOT `tool_output`)
- `tool_use_id` — Unique identifier for this tool invocation

**SessionStart** adds:
- `source` — One of: `startup`, `resume`, `clear`, `compact`
- `model` — The model being used
- `agent_type` (optional) — Present when running as a subagent

**SubagentStop** adds:
- `agent_id` — Identifier of the subagent that stopped
- `agent_transcript_path` — Path to the subagent's transcript
- `stop_hook_active` — Boolean indicating if a stop hook is running

**Stop** adds:
- `stop_hook_active` — Boolean. Critical for preventing infinite loops:
  if true, the hook is already running inside a stop sequence. Do not
  trigger further stop logic.

## Best Practices

- **Security hooks MUST use exit 2** to block dangerous operations. Exit 1
  logs a warning but does not prevent the action.
- **Delegate to external scripts** rather than writing complex inline shell
  commands. Scripts are easier to test, version, and debug.
- **Keep timeouts short.** Hooks run synchronously in the critical path.
  A slow hook degrades the entire session experience.
- **Check `stop_hook_active`** in Stop hooks to avoid infinite recursion.
- **Use PreToolUse for guardrails** — validate tool inputs before execution.
- **Use PostToolUse for logging** — capture tool outputs for audit trails.
- **Use SessionStart for environment setup** — validate prerequisites,
  set environment variables, display reminders.
