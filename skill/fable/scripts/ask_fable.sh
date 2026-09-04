#!/usr/bin/env bash
set -euo pipefail

# The Claude CLI may be installed under another name (e.g. claude-code) or
# outside PATH; FABLE_CLAUDE_BIN overrides the binary to invoke.
claude_bin="${FABLE_CLAUDE_BIN:-claude}"

if ! command -v "$claude_bin" >/dev/null 2>&1; then
  echo "Claude Code CLI '$claude_bin' is not available on PATH (set FABLE_CLAUDE_BIN to override)." >&2
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
  model_candidates=()
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

# Drop duplicate candidates (settings.json and stats-cache.json often overlap).
# Keep first-seen order; no associative arrays (bash 3.2 compatibility).
if ((${#model_candidates[@]} > 1)); then
  unique_candidates=()
  for candidate in "${model_candidates[@]}"; do
    already_seen=0
    for kept in ${unique_candidates[@]+"${unique_candidates[@]}"}; do
      [[ "$kept" == "$candidate" ]] && { already_seen=1; break; }
    done
    ((already_seen)) || unique_candidates+=("$candidate")
  done
  model_candidates=(${unique_candidates[@]+"${unique_candidates[@]}"})
fi

response=""
selected_model=""
for model in "${model_candidates[@]}"; do
  model_args=()
  [[ -n "$model" ]] && model_args=(--model "$model")
  # bash < 4.4 (e.g. macOS system bash 3.2) treats "${arr[@]}" on an empty
  # array as an unbound variable under set -u; the + guard expands to nothing.
  set +e
  candidate_response="$("$claude_bin" \
    --print \
    "${model_args[@]+"${model_args[@]}"}" \
    --effort "$fable_effort" \
    --permission-mode dontAsk \
    --tools "" \
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

printf 'Fable 5.1 speaks (%s):\n\n%s\n' "$selected_model" "$response"
