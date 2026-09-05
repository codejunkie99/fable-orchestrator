#!/usr/bin/env bash
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  echo "Claude Code CLI is not available on PATH." >&2
  exit 127
fi

if [[ $# -gt 0 ]]; then
  packet="$*"
else
  packet="$(cat)"
fi

if [[ -z "${packet//[[:space:]]/}" ]]; then
  echo "Provide a non-empty orchestration packet on stdin or as arguments." >&2
  exit 64
fi

system_prompt='You are Claude Fable 5.1, the orchestration controller for Codex. You plan and adjudicate only; never assign yourself implementation. Use only the supplied packet. Return a concise executable task graph, not implementation. For each node specify: id, purpose, dependencies, recommended model or agent type chosen only from the supplied callable menu, exclusive file or responsibility ownership, expected output, verification, and stop condition. Every implementation node must use GPT-5.6 Luna or DeepSeek V4 Flash and no other model. Identify nodes safe to run in parallel. Minimize the number of agents. Preserve the user scope and approval boundaries. End with an integration and final-verification node. Do not expose chain-of-thought; provide decisions and brief rationale only.

Apply this classifier only when the user did not explicitly choose an allowed implementation route. Loop construction, repeated iteration, and high-throughput mechanical work use a callable OpenCode Go agent pinned to opencode-go/deepseek-v4-flash. All other implementation prefers a callable OpenCode Go agent pinned to opencode-go-responses/gpt-5.6-luna, then opencode-go/deepseek-v4-flash. Never assign implementation to any other model. Planning, research, and review use normal task fit but remain orchestration support, not implementation. Fable 5.1 adjudication stays outside the worker graph. Prefer a callable agent_type that pins both model and provider over a raw cross-provider model string, and classify by that pin rather than the agent display name. A model merely discovered in local config is not callable. If neither allowed implementation route is callable, report the blocker; never invent or silently substitute a model or agent. After any applicable approval gate, start the answer with one short line per ready assignment in the form: Agent — Model: bounded responsibility.'

fable_effort="${FABLE_EFFORT:-low}"
if [[ -n "${FABLE_MODEL:-}" ]]; then
  model_candidates=("$FABLE_MODEL")
elif [[ -n "${FABLE_MODEL_CANDIDATES:-}" ]]; then
  read -r -a model_candidates <<<"$FABLE_MODEL_CANDIDATES"
else
  # This skill exists to route to Fable, so try the local Fable aliases first.
  # Whatever the discovery below finds is a fallback, never the default: the
  # configured default model of the user is not Fable and must not answer as Fable.
  model_candidates=(fable claude-fable-5-1)
  # Claude Code does not expose a portable model-list command. Derive model IDs
  # from the user's own settings and usage cache instead of shipping a catalog.
  if command -v jq >/dev/null 2>&1; then
    for model_file in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" \
      "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json.bak" \
      "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/stats-cache.json"; do
      [[ -f "$model_file" ]] || continue
      while IFS= read -r model; do
        [[ -n "$model" ]] && model_candidates+=("$model")
      done < <(jq -r '.. | objects | .model? // empty, (.modelUsage? // {} | keys[])' "$model_file" 2>/dev/null)
    done
  fi
  # An empty model means: use Claude Code's current locally configured model.
  ((${#model_candidates[@]})) || model_candidates=("")
fi

response=""
selected_model=""
for model in "${model_candidates[@]}"; do
  model_args=()
  [[ -n "$model" ]] && model_args=(--model "$model")
  set +e
  candidate_response="$(claude \
    --print \
    "${model_args[@]}" \
    --effort "$fable_effort" \
    --permission-mode dontAsk \
    --tools "" \
    --strict-mcp-config \
    --no-session-persistence \
    --output-format text \
    --system-prompt "$system_prompt" \
    "$packet" 2>&1)"
  candidate_status=$?
  set -e
  if [[ $candidate_status -eq 0 ]]; then
    response="$candidate_response"
    selected_model="${model:-default}"
    break
  fi
done

if [[ -z "$selected_model" ]]; then
  echo "No usable local Claude model was found. Tried: ${model_candidates[*]}." >&2
  exit 69
fi

if [[ "$selected_model" == *fable* ]]; then
  printf 'Fable 5.1 speaks (%s):\n\n%s\n' "$selected_model" "$response"
else
  echo "No Fable model was callable; ${selected_model} answered instead." >&2
  printf 'Orchestration answer from %s, NOT Fable 5.1:\n\n%s\n' "$selected_model" "$response"
fi
