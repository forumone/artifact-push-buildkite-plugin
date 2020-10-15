# ABOUT THIS FILE
#
# This file contains functions related to the git configuration.

# Usage:
#   validate-git-config
#
# This function validates that, for the git user and email configuration, either:
# 1. Explicit configuration is present, or
# 2. `git config` returns a non-zero exit code when retrieving the value.
validate-git-config() {
  local failures=0

  local user
  user="$(get-config git user)"
  if test -z "$user" && ! git config user.name >/dev/null 2>/dev/null; then
    error "No Git user found."
    error "Ensure that either the 'name' key is set in the Git configuration, or that"
    error "'git config user.name' is set."

    failures=$((failures + 1))
  fi

  local email
  email="$(get-config git email)"
  if test -z "$email" && ! git config user.email >/dev/null 2>/dev/null; then
    error "No Git email found."
    error "Ensure that either the 'email' key is set in the Git configuration, or that"
    error "'git config user.email' is set."
    failures=$((failures + 1))
  fi

  [ "$failures" -eq 0 ]
}

# Usage:
#   git-user
#
# This function determines the username to use in the artifact push's git configuration.
# It respects plugin configuration, but falls back to the Buildkite agent's "user.name"
# git config.
git-user() {
  local config
  config="$(get-config git user)"

  if test -n "$config"; then
    echo -n "$config"
  else
    git config user.name
  fi
}

# Usage:
#   git-email
#
# This function determines the email address to use in the artifact push's git
# configuration. It respects plugin configuration, but falls back to the Buildkite agent's
# "user.email" git config.
git-email() {
  local config
  config="$(get-config git email)"

  if test -n "$config"; then
    echo -n "$config"
  else
    git config user.email
  fi
}

# Usage
#   git-commit-message
#
# Returns the message to be used when the deploy script generates its commit. The message
# can be overridden in the plugin configuration, with a default that is auto-generated.
git-commit-message() {
  local message
  message="$(get-config message)"

  if test -n "$message"; then
    echo -n "$message"
  else
    echo "$BUILDKITE_ORGANIZATION_SLUG/$BUILDKITE_PIPELINE_SLUG: Build $BUILDKITE_BUILD_NUMBER for $BUILDKITE_BRANCH"
  fi
}
