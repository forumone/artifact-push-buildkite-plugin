# ABOUT THIS FILE
#
# This file contains functions related to the git configuration.

# Usage:
#   validate-git-config
#
# At present, this function does nothing and always succeeds.
validate-git-config() {
  true
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
