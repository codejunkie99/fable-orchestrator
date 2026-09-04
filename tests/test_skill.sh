#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
skill_root="$repo_root/skill/fable"
svg_path="$repo_root/assets/fable-orchestrator.svg"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "$skill_root/SKILL.md" ]] || fail 'SKILL.md is missing'
[[ -f "$skill_root/scripts/ask_fable.sh" ]] || fail 'ask_fable.sh is missing'
[[ -f "$skill_root/agents/openai.yaml" ]] || fail 'openai.yaml is missing'
[[ -x "$skill_root/scripts/ask_fable.sh" ]] || fail 'ask_fable.sh is not executable'

bash -n "$skill_root/scripts/ask_fable.sh"
bash -n "$repo_root/install.sh"

required_strings=(
  'Claude Fable 5.1'
  'GPT-5.6 Luna'
  'DeepSeek V4 Flash'
  'opencode-go/'
  'opencode-go-responses/'
)
for required in "${required_strings[@]}"; do
  rg -Fq "$required" "$skill_root/SKILL.md" || fail "missing required routing string: $required"
done

awk '
  /^interface:[[:space:]]*$/ { interface=1; next }
  /^[[:space:]]+display_name:[[:space:]]*"[^\"]+"[[:space:]]*$/ { display=1; next }
  /^[[:space:]]+short_description:[[:space:]]*"[^\"]+"[[:space:]]*$/ { short=1; next }
  /^[[:space:]]+default_prompt:[[:space:]]*"[^\"]+"[[:space:]]*$/ { prompt=1; next }
  END { exit !(interface && display && short && prompt) }
' "$skill_root/agents/openai.yaml" || fail 'openai.yaml failed basic YAML structure check'

if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout "$svg_path" || fail 'SVG is not valid XML'
fi

rg -Fq 'viewBox="0 0 1200 600"' "$svg_path" || fail 'SVG viewBox is not 0 0 1200 600'
rg -Fq 'FABLE 5.1' "$svg_path" || fail 'SVG is missing the Fable planning node'
rg -Fq 'GPT-5.6 LUNA' "$svg_path" || fail 'SVG is missing the Luna worker node'
rg -Fq 'DEEPSEEK V4 FLASH' "$svg_path" || fail 'SVG is missing the DeepSeek worker node'
if rg -n -i 'gradient|<filter([[:space:]>]|$)|<image([[:space:]>]|$)|url\(|@font-face|@import|fonts\.(googleapis|gstatic)|href=[^[:space:]]*(https?:|//)' "$svg_path"; then
  fail 'SVG contains a gradient, filter, external image, or external font reference'
fi

temp_root="$(mktemp -d "${TMPDIR:-/tmp}/fable-orchestrator.XXXXXX")"
trap 'rm -rf "$temp_root"' EXIT
temp_home="$temp_root/home"
mkdir -p "$temp_home"

dry_run_output="$temp_root/dry-run.txt"
HOME="$temp_home" FABLE_SKILLS_DIR= "$repo_root/install.sh" --dry-run >"$dry_run_output"
[[ ! -e "$temp_home/.codex" ]] || fail 'dry-run created a directory under HOME'
rg -Fq "$temp_home/.codex/skills/fable" "$dry_run_output" || fail 'dry-run omitted the default destination'

copy_home="$temp_root/copy-home"
HOME="$copy_home" "$repo_root/install.sh" --copy >/dev/null
for relative_path in SKILL.md scripts/ask_fable.sh agents/openai.yaml; do
  cmp -s "$skill_root/$relative_path" "$copy_home/.codex/skills/fable/$relative_path" || fail "installed copy differs: $relative_path"
done
HOME="$copy_home" "$repo_root/install.sh" --copy >/dev/null

source_candidates=()
if [[ -n "${FABLE_SOURCE_DIR:-}" ]]; then
  source_candidates+=("$FABLE_SOURCE_DIR")
fi
for installed_source in "${source_candidates[@]}"; do
  [[ -d "$installed_source" ]] || continue
  for relative_path in SKILL.md scripts/ask_fable.sh agents/openai.yaml; do
    cmp -s "$skill_root/$relative_path" "$installed_source/$relative_path" || fail "source copy differs: $installed_source/$relative_path"
  done
  break
done

# Keep the scan practical: this test file contains the detection patterns, so exclude it.
if rg -n --hidden --glob '!.git/**' --glob '!tests/test_skill.sh' \
  -e '-----BEGIN [A-Z ]*PRIVATE KEY-----' \
  -e 'AKIA[0-9A-Z]{16}' \
  -e 'gh[pousr]_[A-Za-z0-9]{20,}' \
  -e 'sk-(ant-)?[A-Za-z0-9_-]{20,}' \
  -e 'xox[baprs]-[A-Za-z0-9-]{20,}' \
  "$repo_root"; then
  fail 'credential-shaped string found in repository'
fi

echo 'PASS: Fable orchestrator repository checks'
