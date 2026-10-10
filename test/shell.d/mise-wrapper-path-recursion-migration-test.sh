#!/bin/bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

migration="$ROOT/migrations/1791626600.sh"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

home="$test_dir/home"
bin_dir="$home/.local/bin"
mkdir -p "$bin_dir"

run_migration() {
  HOME="$home" PATH="$ROOT/bin:$PATH" bash -euo pipefail "$migration" >/dev/null
}

write_stale_wrapper() {
  local command=$1 package=$2 bin=$3

  cat >"$bin_dir/$command" <<EOF
#!/bin/bash
export MISE_MINIMUM_RELEASE_AGE=0
mise use -g --quiet "$package" || exit 1
exec mise x "$package" -- "$bin" "\$@"
EOF
  chmod +x "$bin_dir/$command"
}

write_stale_wrapper claude claude claude
write_stale_wrapper omp github:can1357/oh-my-pi omp
write_stale_wrapper ghui npm:@kitlangton/ghui ghui

# Older wrapper from before --quiet
cat >"$bin_dir/older-tool" <<'EOF'
#!/bin/bash
export MISE_MINIMUM_RELEASE_AGE=0
mise use -g "github:someone/older-tool" || exit 1
exec mise x "github:someone/older-tool" -- "older-tool" "$@"
EOF
chmod +x "$bin_dir/older-tool"

# Escaped wrapper written between Aug 24 and Sep 7 without quotes
cat >"$bin_dir/escaped-tool" <<'EOF'
#!/bin/bash
export MISE_MINIMUM_RELEASE_AGE=0
mise use -g --quiet github:someone/escaped-tool || exit 1
exec mise x github:someone/escaped-tool -- escaped-tool "$@"
EOF
chmod +x "$bin_dir/escaped-tool"

run_migration

grep -qF 'if [[ ":$PATH:" == *":$HOME/.local/bin:"*' "$bin_dir/claude" ||
  fail "migration checks whether ~/.local/bin is in PATH"
grep -qF 'new_path=()' "$bin_dir/claude" ||
  fail "migration updates wrapper to reorder PATH"
grep -qF 'new_path+=("$HOME/.local/bin")' "$bin_dir/claude" ||
  fail "migration appends ~/.local/bin to new_path"
grep -qF 'exec mise x "claude" -- "claude" "$@"' "$bin_dir/claude" ||
  fail "migration executes claude via mise x"
pass "migration regenerates stale wrapper with PATH reordering"

grep -qF 'exec mise x "github:can1357/oh-my-pi" -- "omp" "$@"' "$bin_dir/omp" ||
  fail "migration preserves package and bin name"
pass "migration preserves package and bin names"

grep -qF 'new_path=()' "$bin_dir/older-tool" ||
  fail "migration updates older wrapper as well"
pass "migration updates older wrapper as well"

grep -qF 'new_path=()' "$bin_dir/escaped-tool" ||
  fail "migration updates escaped wrapper as well"
pass "migration updates escaped wrapper as well"

# Idempotency: running a second time makes no changes
before=$(cat "$bin_dir/claude")
run_migration
[[ $(cat "$bin_dir/claude") == "$before" ]] || fail "migration is idempotent"
pass "migration is idempotent"

# Hand-written or modified wrappers should remain untouched
cat >"$bin_dir/customized" <<'EOF'
#!/bin/bash
export MISE_MINIMUM_RELEASE_AGE=0
export CUSTOM=1
mise use -g --quiet "customized" || exit 1
exec mise x "customized" -- "customized" "$@"
EOF
chmod +x "$bin_dir/customized"
custom_before=$(cat "$bin_dir/customized")

run_migration
[[ $(cat "$bin_dir/customized") == "$custom_before" ]] ||
  fail "migration leaves customized wrapper alone"
pass "migration leaves customized wrapper alone"
