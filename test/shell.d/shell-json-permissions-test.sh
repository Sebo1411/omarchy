#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

home="$tmpdir/home"
omarchy_path="$tmpdir/omarchy"
mkdir -p "$home/.config/omarchy" "$omarchy_path/config/omarchy" "$omarchy_path/bin"

# 1. Test migration tightening existing 0644 shell.json to 0600
echo '{"version":1,"plugins":[]}' >"$home/.config/omarchy/shell.json"
chmod 644 "$home/.config/omarchy/shell.json"
[[ $(stat -c '%a' "$home/.config/omarchy/shell.json") == "644" ]] || fail "fixture shell.json is 644"

HOME="$home" bash -euo pipefail "$ROOT/migrations/1791573437.sh"
migrated_mode=$(stat -c '%a' "$home/.config/omarchy/shell.json")
[[ $migrated_mode == "600" ]] || fail "migration enforces mode 0600 on shell.json" "got: $migrated_mode"
pass "migration enforces mode 0600 on existing shell.json"

# 2. Test omarchy-shell-config commit() ensures mode 0600
mock_bin="$tmpdir/mock-bin"
mkdir -p "$mock_bin"
cat >"$mock_bin/omarchy-shell" <<'SH'
#!/bin/bash
exit 0
SH
chmod +x "$mock_bin/omarchy-shell"

echo '{"version":1,"bar":{"layout":{"left":[],"center":[],"right":[]}},"plugins":[]}' >"$omarchy_path/config/omarchy/shell.json"
chmod 644 "$home/.config/omarchy/shell.json"

(
  export HOME="$home"
  export OMARCHY_PATH="$omarchy_path"
  export PATH="$mock_bin:$PATH"
  source "$ROOT/bin/omarchy-shell-config"
  commit '.plugins += ["test.plugin"]'
)

commit_mode=$(stat -c '%a' "$home/.config/omarchy/shell.json")
[[ $commit_mode == "600" ]] || fail "omarchy-shell-config commit enforces mode 0600" "got: $commit_mode"
pass "omarchy-shell-config commit enforces mode 0600 on shell.json"

# 3. Test refresh-config creates mode 0600 under umask 022
rm -f "$home/.config/omarchy/shell.json"
(
  umask 022
  HOME="$home" OMARCHY_PATH="$omarchy_path" "$ROOT/bin/omarchy-refresh-config" omarchy/shell.json >/dev/null
)
refresh_mode=$(stat -c '%a' "$home/.config/omarchy/shell.json")
[[ $refresh_mode == "600" ]] || fail "omarchy-refresh-config creates shell.json with mode 0600" "got: $refresh_mode"
pass "omarchy-refresh-config creates shell.json with mode 0600 under umask 022"
