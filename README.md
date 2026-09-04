# Fable orchestrator

Fable is a small, local-first routing skill for Codex. Claude Fable 5.1 plans and adjudicates; it does not write code or own the workspace. Codex remains the runtime and delegates bounded implementation work to OpenCode Go agents:

- GPT-5.6 Luna handles normal implementation.
- DeepSeek V4 Flash handles loops, repeated iteration, and high-throughput implementation.
- Fable 5.1 remains outside the implementation graph for planning and final adjudication.

The skill consumes the callable `opencode-go/` and `opencode-go-responses/` agents supplied by Codex Router. It does not ship a proxy, dashboard, model catalog, credential store, or API key. Configure OpenCode Go once in the router, then restart Codex after changing provider or agent definitions.

![Fable orchestrator: planning, implementation, and verification](assets/fable-orchestrator.svg)

## Repository layout

```text
skill/fable/
├── SKILL.md
├── agents/openai.yaml
└── scripts/ask_fable.sh
assets/fable-orchestrator.svg
install.sh
tests/test_skill.sh
```

The three files under `skill/fable/` are the installable skill. `ask_fable.sh` is executable and invokes Claude Code's local `fable` alias with no session persistence. The packet passed to it must contain decisions and workspace facts only; never put credentials in a packet.

## Prerequisites

- `bash` and the Claude Code CLI (`claude` on PATH, locally authenticated) for `ask_fable.sh`.
- `jq` is optional: with it, `ask_fable.sh` derives model candidates from your Claude settings and usage cache; without it, the helper falls back to Claude Code's configured default model.
- `rg` (ripgrep) is required only for `tests/test_skill.sh`.

## Install

From this repository:

```bash
./install.sh --dry-run
./install.sh --copy
```

`--dry-run` prints the exact destination and copy operations without creating files. `--copy` installs to `~/.codex/skills/fable`, creates only the required directories, and is safe to run again. Use `--target DIR` to select another skills directory:

```bash
./install.sh --copy --target "$PWD/.local/codex/skills"
```

`FABLE_SKILLS_DIR` sets the same default when `--target` is not passed. At runtime, `FABLE_MODEL`, `FABLE_MODEL_CANDIDATES`, and `FABLE_EFFORT` override the helper's model discovery and effort level, and `FABLE_CLAUDE_BIN` selects the Claude CLI binary when it is not named `claude` on PATH.

The installer reads only this repository and the destination path. It never reads, creates, or modifies credentials. Start a new Codex task after changing the provider or agent definitions.

## Use

Invoke the skill with an objective:

```text
$fable build the feature
```

Fable returns a bounded graph. Codex validates the graph, starts ready workers in parallel when useful, collects their evidence, verifies the result, and asks Fable to adjudicate when the task needs another decision. Every implementation node must use GPT-5.6 Luna or DeepSeek V4 Flash. If neither allowed OpenCode Go route is callable, the workflow reports the blocker instead of inventing a model.

## Test

Run the repository's dependency-light checks:

```bash
tests/test_skill.sh
```

The test checks shell syntax, the copied source files, required routing strings, basic YAML structure, optional `xmllint` XML validation, SVG safety constraints, a temporary-home dry run, an idempotent copy, and common credential-shaped strings. It does not require PyYAML or a live Claude login.

## License

MIT. See [LICENSE](LICENSE).
