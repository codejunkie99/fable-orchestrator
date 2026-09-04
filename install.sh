#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: install.sh --dry-run|--copy [--target DIR]

Install the Fable skill under DIR/fable. DIR defaults to ~/.codex/skills.
USAGE
}

mode=''
target_root="${FABLE_SKILLS_DIR:-}"

while (($#)); do
  case "$1" in
    --dry-run)
      [[ -z "$mode" ]] || { echo 'Choose only one of --dry-run or --copy.' >&2; exit 64; }
      mode='dry-run'
      ;;
    --copy)
      [[ -z "$mode" ]] || { echo 'Choose only one of --dry-run or --copy.' >&2; exit 64; }
      mode='copy'
      ;;
    --target)
      (($# >= 2)) || { echo '--target requires a directory.' >&2; exit 64; }
      target_root="$2"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
  shift
done

[[ -n "$mode" ]] || { usage >&2; exit 64; }
if [[ -z "$target_root" ]]; then
  [[ -n "${HOME:-}" ]] || { echo 'Set HOME or pass --target DIR.' >&2; exit 64; }
  target_root="$HOME/.codex/skills"
fi
[[ -n "$target_root" ]] || { echo 'The target directory cannot be empty.' >&2; exit 64; }
[[ "$target_root" != '/' ]] || { echo 'Refusing to install directly under /. Use a skills directory.' >&2; exit 64; }
if [[ -e "$target_root" && ! -d "$target_root" ]]; then
  echo "Target exists and is not a directory: $target_root" >&2
  exit 73
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source_root="$repo_root/skill/fable"
destination="$target_root/fable"

for relative_path in SKILL.md scripts/ask_fable.sh agents/openai.yaml; do
  [[ -f "$source_root/$relative_path" ]] || {
    echo "Missing repository file: $source_root/$relative_path" >&2
    exit 66
  }
done

if [[ "$mode" == 'dry-run' ]]; then
  printf 'Would create directory: %s\n' "$destination/scripts"
  printf 'Would create directory: %s\n' "$destination/agents"
  printf 'Would copy: %s\n' "$destination/SKILL.md"
  printf 'Would copy: %s\n' "$destination/scripts/ask_fable.sh"
  printf 'Would copy: %s\n' "$destination/agents/openai.yaml"
  printf 'Would set executable mode: %s\n' "$destination/scripts/ask_fable.sh"
  exit 0
fi

if [[ -e "$destination" && ! -d "$destination" ]]; then
  echo "Destination exists and is not a directory: $destination" >&2
  exit 73
fi

mkdir -p "$destination/scripts" "$destination/agents"
cp "$source_root/SKILL.md" "$destination/SKILL.md"
cp "$source_root/scripts/ask_fable.sh" "$destination/scripts/ask_fable.sh"
cp "$source_root/agents/openai.yaml" "$destination/agents/openai.yaml"
chmod 0755 "$destination/scripts/ask_fable.sh"

printf 'Installed Fable skill at %s\n' "$destination"
