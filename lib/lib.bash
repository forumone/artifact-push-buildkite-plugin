root="$(dirname "${BASH_SOURCE[0]}")"

# shellcheck source=lib/util.bash
. "$root/util.bash"

# shellcheck source=lib/config.bash
. "$root/config.bash"

# shellcheck source=lib/ssh.bash
. "$root/ssh.bash"

# shellcheck source=lib/git.bash
. "$root/git.bash"

# shellcheck source=lib/branches.bash
. "$root/branches.bash"

# shellcheck source=lib/files.bash
. "$root/files.bash"

# Usage:
#   validate-config
#
# This is the top-level configuration validation function. It should be used as the entry
# point for configuration validation instead of directly using the sub-validation
# functions found in the other library files.
validate-config() {
  failures=0

  if ! validate-base-config; then
    failures=$((failures + 1))
  fi

  if ! validate-git-config; then
    failures=$((failures + 1))
  fi

  if ! validate-ssh-config; then
    failures=$((failures + 1))
  fi

  if ! build-branch-config; then
    failures=$((failures + 1))
  fi

  [ $failures -eq 0 ]
}
