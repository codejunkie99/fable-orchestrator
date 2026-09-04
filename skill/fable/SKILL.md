---
name: fable
description: Use the locally authenticated Claude Code Fable 5.1 model only as the orchestrator for a task, then execute implementation with GPT-5.6 Luna or DeepSeek V4 Flash. Use when the user invokes $fable or asks Fable to orchestrate Codex agents.
---

# Fable orchestrator

Claude Fable 5.1 supplies orchestration decisions only. Codex remains the runtime that
spawns workers, owns files, runs tools, verifies the result, and reports to the
user.

## Invocation

Treat everything after `$fable` as the objective. Fable 5.1 always owns
orchestration. Implementation workers are restricted to GPT-5.6 Luna and
DeepSeek V4 Flash:

- `$fable build the feature`
- `$fable debug this; implementer: gpt-5.6-luna`

Model names are requests, not guesses. Before dispatch, inspect the current
`spawn_agent` tool description and custom agent roles. Use only models or roles
that are currently callable. If a requested model is unavailable, say so and
use the closest available choice only when that substitution is low-risk;
otherwise ask for a replacement.

For the simplest automatic path, the user can provide only an objective. Apply
this ordered classifier when they did not explicitly choose a route:

- loop construction, repeated iteration, or high-throughput mechanical work:
  use a callable OpenCode Go agent pinned to `opencode-go/deepseek-v4-flash`;
- implementation: use a callable OpenCode Go agent pinned to
  `opencode-go-responses/gpt-5.6-luna`, then
  `opencode-go/deepseek-v4-flash`;
- planning, research, review, and other work: choose by normal task fit.

Prefer an exposed `agent_type` that pins both model and provider. Never infer
callability from a config file or send a raw model override across providers.
An explicit implementation choice wins only when it is GPT-5.6 Luna or DeepSeek
V4 Flash. Do not assign implementation to any other model. After any applicable
approval gate, state only `<Agent> — <Model>: <bounded responsibility>`, then
immediately start. Classify by the callable model pin, not the agent's display
name. Do not show the full model catalog unless asked.

## OpenCode Go compatibility

Codex Router owns OpenCode Go provider setup, model discovery, and credentials;
Fable must not duplicate them. A user adds the OpenCode Go API key once through
the router's local secure setup. Never request or paste an API key in chat or
store it in a Fable packet. Fable consumes only callable `opencode-go/` and
`opencode-go-responses/` agents supplied by Codex, so it needs no proxy,
dashboard, or second static model list. Start a new Codex task after changing
the provider or agent definitions.

## Workflow

1. Read the objective and relevant local instructions. Inspect enough of the
   workspace to give Fable facts rather than assumptions.
2. Build a compact orchestration packet containing the objective, acceptance
   criteria, workspace context, constraints, protected files, evidence already
   gathered, callable worker menu, concurrency limit, and user preferences.
3. Send the packet to `scripts/ask_fable.sh`. Use Claude's `fable` alias; do not
   read, copy, print, or modify Claude credentials.
4. Require a bounded task graph with role, model or agent type, owned files or
   responsibility, dependencies, expected output, verification, and a stop
   condition for every node. Reject any implementation node assigned to a model
   other than GPT-5.6 Luna or DeepSeek V4 Flash.
   Fable 5.1 adjudication remains outside the worker graph.
5. Validate the graph against the actual task and current tools. Codex has final
   responsibility for safety and scope. Do not execute invented models, unsafe
   actions, or work outside the user's request.
6. Spawn independent ready nodes in parallel, up to the live collaboration
   limit. Tell every code-writing worker its ownership and that other agents
   share the workspace, so it must preserve and accommodate their edits.
7. Collect results, inspect changed files, and run proportionate verification.
   For complex work, send a concise results packet back through the helper for
   the next graph or final adjudication. Cap this at three Fable calls unless
   the user asks to continue.
8. Finish only when acceptance criteria and verification pass. Report selected
   models, material changes, and concrete proof.

Whenever the helper returns Fable's orchestration output, display it verbatim
under this exact heading:

```text
Fable 5.1 speaks:
```

Do not relabel ordinary Codex or worker-agent output as Fable speech.

## Boundaries

- Fable plans and adjudicates; it does not silently replace the Codex workers.
- Exchange decisions, evidence, task packets, diffs, test results, and blockers,
  not hidden reasoning.
- Orchestration does not expand authorization. Publishing, deployment,
  destructive operations, spending, and external messages retain their normal
  approval boundaries.
- If delegation adds no value, use one worker or execute directly after the
  Fable plan.

## Calling Fable

Pass the packet as standard input:

```bash
printf '%s' "$PACKET" | ~/.codex/skills/fable/scripts/ask_fable.sh
```

Do not place secrets in the packet. The helper uses the existing local Claude
Code authentication and creates no persistent Claude session.
