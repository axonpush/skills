#!/usr/bin/env bash
set -eo pipefail
export GITHUB_WORKSPACE="$CI_WORKSPACE"
export GITHUB_SHA="$CI_COMMIT_SHA"
export GITHUB_REF="$CI_COMMIT_REF"
export GITHUB_REF_NAME="${CI_COMMIT_REF##refs/heads/}"
GITHUB_REF_NAME="${GITHUB_REF_NAME##refs/tags/}"
export GITHUB_REPOSITORY="$CI_REPO"
export GITHUB_REPOSITORY_OWNER="$CI_REPO_OWNER"
export GITHUB_EVENT_NAME="$CI_PIPELINE_EVENT"
if [ "$GITHUB_EVENT_NAME" = manual ]; then GITHUB_EVENT_NAME=workflow_dispatch; fi
export RUNNER_TEMP="$(mktemp -d /tmp/woodpecker.XXXXXX)"
export GITHUB_ENV="$RUNNER_TEMP/environment" GITHUB_OUTPUT="$RUNNER_TEMP/output"
touch "$GITHUB_ENV" "$GITHUB_OUTPUT"
export MISE_TRUSTED_CONFIG_PATHS="$CI_WORKSPACE"

printf '%s\n' 'Install shellcheck and yq'
(
  cd .
sudo apt-get update
sudo apt-get install -y shellcheck
sudo wget -qO /usr/local/bin/yq \
  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
yq --version
)

printf '%s\n' 'Shellcheck helpers'
(
  cd .
shopt -s nullglob
files=(skills/axonpush-integrate/helpers/*.sh)
if [ ${#files[@]} -eq 0 ]; then
  echo "No helper scripts found yet — skipping shellcheck."
  exit 0
fi
shellcheck "${files[@]}"
)

printf '%s\n' 'Lint SKILL.md frontmatter'
(
  cd .
set -euo pipefail
status=0
# Extract the YAML frontmatter (lines between the first and second
# `---`) before passing to yq. Feeding the whole markdown file to
# yq trips its tokenizer on backtick-led lines or other non-YAML
# markdown content past the frontmatter.
extract_frontmatter() {
  awk '
    /^---[[:space:]]*$/ { n++; if (n == 2) exit; next }
    n == 1 { print }
  ' "$1"
}
while IFS= read -r -d '' f; do
  fm=$(extract_frontmatter "$f")
  if [ -z "$fm" ]; then
    echo "::error file=$f::missing or empty YAML frontmatter (expected '---' delimiters)"
    status=1
    continue
  fi
  name=$(printf '%s\n' "$fm" | yq e '.name' - 2>/dev/null || true)
  desc=$(printf '%s\n' "$fm" | yq e '.description' - 2>/dev/null || true)
  if [ -z "$name" ] || [ "$name" = "null" ]; then
    echo "::error file=$f::missing or empty 'name' in frontmatter"
    status=1
  fi
  if [ -z "$desc" ] || [ "$desc" = "null" ]; then
    echo "::error file=$f::missing or empty 'description' in frontmatter"
    status=1
  fi
  dir=$(basename "$(dirname "$f")")
  if [ "$name" != "$dir" ]; then
    echo "::error file=$f::frontmatter name '$name' does not match directory '$dir'"
    status=1
  fi
done < <(find skills -name SKILL.md -print0)
exit $status
)
