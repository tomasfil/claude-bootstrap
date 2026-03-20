# Hook Reference

## Hook Event Lifecycle

Events fire in this order during a session:

1. **SessionStart** — session begins (startup, resume, clear, or compact)
2. **InstructionsLoaded** (v2.1.69+) — after CLAUDE.md and rules are loaded
3. **Notification** — system notification received
4. **UserPromptSubmit** — user sends a message
5. **PermissionRequest** — before showing a permission prompt
6. **PreToolUse** — before a tool executes
7. **PostToolUse** — after a tool executes successfully
8. **PostToolUseFailure** — after a tool execution fails
9. **PreCompact** — before context compaction
10. **SubagentStart** — subagent spawned
11. **SubagentStop** — subagent finished
12. **TaskCompleted** — a task finishes
13. **Stop** — model stops generating
14. **SessionEnd** — session terminates

Additional events:
- **ConfigChange** — settings.json or CLAUDE.md modified
- **WorktreeCreate** — git worktree created (by isolation agents)
- **WorktreeRemove** — git worktree removed
- **Setup** — first-time project setup
- **TeammateIdle** — teammate agent becomes idle

## Exit Codes

| Code | Meaning | Behavior |
|------|---------|----------|
| 0 | Success / proceed | Action continues normally |
| 1 | Non-blocking error | Action proceeds; stderr shown only in verbose mode |
| 2 | Block | Action is blocked; stderr shown to user as error |

## Hook Types

### command
Runs a shell command. Receives JSON on stdin. Stdout/stderr handled per exit code.

### prompt
Single-turn model evaluation. The hook text is sent to a model for evaluation. No tool access.

### http
Sends a POST request with JSON payload to an endpoint. Response status determines proceed/block.

### agent
Spawns a subagent with tool access. The hook body is the agent's prompt. Has its own context window.

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
- `tool_name` — name of the tool about to execute
- `tool_input` — the tool's input parameters (object)
- `tool_use_id` — unique ID for this tool invocation

**PostToolUse** adds:
- `tool_name` — name of the tool that executed
- `tool_input` — the tool's input parameters (object)
- `tool_response` — the tool's response (NOT `tool_output` — this is a common mistake)
- `tool_use_id` — unique ID for this tool invocation

**SessionStart** adds:
- `source` — one of: `startup`, `resume`, `clear`, `compact`
- `model` — the model being used
- `agent_type` (optional) — present if session is an agent

**SubagentStop** adds:
- `agent_id` — identifier of the subagent
- `agent_transcript_path` — path to the subagent's transcript
- `stop_hook_active` — boolean, whether a Stop hook is active

**Stop** adds:
- `stop_hook_active` — boolean. **Critical for preventing infinite loops.** If true, a Stop hook is already running — do not trigger another.

## Best Practices

- **Security hooks MUST use exit 2** to block dangerous actions. Exit 1 allows the action to proceed.
- **Delegate to external scripts** rather than inline shell commands. Scripts are testable, version-controlled, and reusable.
- **Keep timeouts short.** Hooks run synchronously and block the action. A slow hook degrades the entire experience.
- **Check `stop_hook_active`** in Stop hooks to prevent infinite recursion.
- **Use PreToolUse for guardrails** — validate tool inputs before execution (e.g., block writes to protected files).
- **Use PostToolUse for auditing** — log tool actions, validate outputs, trigger follow-up actions.
- **SessionStart for environment setup** — load context, set environment variables, check prerequisites.
