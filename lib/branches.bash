# ABOUT THIS FILE
#
# This file contains functions that interact with this plugin's branch mapping
# configuration.

# The branch configuration is serialized into a JSON object. We manipulate this object
# using a few jq filters (see below). There appears to be some kind of initialization (or
# re-initialization) bug in bats that causes associative arrays to get somehow corrupted,
# so our use of jq here is an attempt to immunize ourselves until we can resolve the
# bats bug and use more "normal" structured configuration.
_branches='{}'

# Usage:
#   branch-config-exists BRANCH
#
# BRANCH: The name of a branch to read data for.
#
# This function returns the string 'true' if configuration exists for the named BRANCH,
# and 'false' otherwise. The primary use for this function is to determine if the user
# accidentally specified a match option in the branches configuration twice.
branch-config-exists() {
  # shellcheck disable=SC2016
  local filter='.[$branch] != null'

  local branch="$1"

  jq "$filter" \
    --arg branch "$branch" \
    <<<"$_branches"
}

# Usage:
#   branch-config-count
#
# This function returns the number of mappings stored in the branch configuration, and is
# intended for use as an error-checking function to ensure the user has specified any
# mappings at all.
branch-config-count() {
  local filter='keys | length'

  jq "$filter" \
    <<<"$_branches"
}

# Usage:
#   branch-set-config BRANCH TARGET REMOTE [TAG]
#
# BRANCH: The name of a branch to set the configuration for.
# TARGET: The target branch to deploy to.
# REMOTE: The remote repository to push to.
# TAG (optional): The Bash expression to use for tagging
#
# This function sets the configuration (target + remote) for the branch named by BRANCH.
# Note that both TARGET and REMOTE are required; it is up to callers of this function to
# follow the conventions documented in this plugin's README.
branch-set-config() {
  # shellcheck disable=SC2016
  local filter='.[$branch] = { $target, $remote, $tag }'

  local branch="$1"
  local target="$2"
  local remote="$3"
  local tag="${4:-}"

  _branches="$(
    jq -c "$filter" \
      --arg branch "$branch" \
      --arg target "$target" \
      --arg remote "$remote" \
      --arg tag "$tag" \
      <<<"$_branches"
  )"
}

# Usage:
#   branch-get-option BRANCH OPTION
#
# BRANCH: The name of the branch to get configuration from.
# OPTION: The name of a configuration option. Must be one of 'target', 'remote', or 'tag'.
#
# This function reads the configuration for the branch named by BRANCH, and returns a
# single option from it. Unlike branch-get-option, this function returns "raw" strings:
# the configuration values are converted into values usable immediately by scripts instead
# of as JSON strings meant for further processing.
branch-get-option() {
  # shellcheck disable=SC2016
  local filter='.[$branch][$option] | strings'

  local branch="$1"
  local option="$2"

  jq -r "$filter" \
    --arg branch "$branch" \
    --arg option "$option" \
    <<<"$_branches"
}

# Usage:
#   build-branch-config
#
# This function populates the all_branches associative array. If any configuration errors
# were detected, this function returns a failure status.
build-branch-config() {
  # Count of issues encountered
  local failures=0

  # When this value is non-empty, it's safe to "commit" the configuration (i.e., call
  # branch-set-config).
  local safe

  # Default remote to use. If there is no remote specified in the branches configuration,
  # we default to the top-level remote.
  local default_remote
  default_remote="$(get-config remote)"

  # Variables corresponding to the options
  local shorthand
  local match
  local remote
  local target
  local tag

  # Used in error reporting
  local existing_target
  local existing_remote

  local index=0
  while true; do
    # Reset safety flag
    safe=1

    # Read all configuration options
    shorthand="$(get-config branches $index)"
    match="$(get-config branches $index match)"
    target="$(get-config branches $index target)"
    remote="$(get-config branches $index remote)"
    tag="$(get-config branches $index tag)"

    # We assume that any non-existed configuration is the end of the array
    if test -z "$shorthand" && test -z "$match" && test -z "$target" && test -z "$remote"; then
      break
    fi

    # If the user specified the shorthand string syntax (yaml: - "branch name"), then
    # expand the values explicitly.
    if test -n "$shorthand"; then
      match="$shorthand"
      target="$shorthand"
      remote=
    fi

    if test -z "$remote"; then
      remote="$default_remote"
    fi

    if test -z "$match"; then
      error "An empty branch match was specified."
      error
      error "If you are using the object form of a branch mapping, remember that the"
      error "match option is required to determine which branch to use when pushing"
      error "the build artifacts."

      # When we find an issue, we 1) clear the safety flag (indicating we shouldn't write
      # this configuration) and 2) increment the number of failures. The safety flag is
      # used just before the end of each loop iteration, but the failure count is used
      # at the end of the function, hence why there are two variables.
      safe=
      failures=$((failures + 1))
    fi

    # If using longhand notation, the "target" option is required.
    if test -n "$match" && test -z "$target"; then
      error "The branch '${match}' has no target to deploy to."
      error
      error "In the branch mapping array, the target option specifies which branch to"
      error "deploy to on the remote repository. This can be used to match another"
      error "repository's conventions (for example, building 'master' but publishing to"
      error "'develop')."

      safe=
      failures=$((failures + 1))
    fi

    # If the branch was already set, then report a failure
    if test "$(branch-config-exists "$match")" = true; then
      existing_target="$(branch-get-option "$match" target)"
      existing_remote="$(branch-get-option "$match" remote)"

      error "The branch '${match}' already has a deployment target of ${existing_target}"
      if test -n "$existing_remote"; then
        error "(The branch is published to ${existing_remote})"
      fi
      error
      error "The same branch cannot be deployed to two different targets. Please ensure"
      error "that there are no issues (typos, for example) that are causing this overlap."

      safe=
      failures=$((failures + 1))
    fi

    if test -n "$safe"; then
      branch-set-config "$match" "$target" "$remote" "$tag"
    fi

    index=$((index + 1))
  done

  [ $failures -eq 0 ]
}

# Usage:
#   is-branch-required
#
# This function determines if a branch mapping is required, per the "require-branch"
# configuration option. If it returns true, then we should exit with failures.
is-branch-required() {
  is-truthy "$(get-config require-branch)"
}

# Usage:
#   get-branch-target
#
# This determines the target branch to push to, based on the value of $BUILDKITE_BRANCH.
# If the return value is empty, then it is safe to assume that the user has not declared a
# mapping for the current branch.
#
# NB. This function should not be run before build-branch-config has been called.
get-branch-target() {
  branch-get-option "$BUILDKITE_BRANCH" target
}

# Usage:
#   get-branch-remote
#
# This determines the remote repository to push to, based on the value of
# $BUILDKITE_BRANCH.
#
# NB. This function must be run after build-branch-config has been called.
get-branch-remote() {
  branch-get-option "$BUILDKITE_BRANCH" remote
}

# Usage:
#   get-branch-tag
#
# This determines the tag to apply to this push, based on the value of
# $BUILDKITE_BRANCH.
#
# NB. This function must be run after build-branch-config has been called.
get-branch-tag() {
  branch-get-option "$BUILDKITE_BRANCH" tag
}

# Usage:
#   dump-branch-config
#
# This outputs a human-readable version of the stored branch config. Used primarily for
# informing the user of our interpretation of the configuration. Each line of output
# is formatted as "$branch: Deploys to $target_branch on remote $target_remote".
#
# NB. This function must be run after build-branch-config has been called.
dump-branch-config() {
  local filter='
    to_entries
      | .[]
      | "\(.key): Deploys to branch \(.value.target) on remote \(.value.remote)"
  '

  jq -r "$filter" \
    <<<"$_branches"
}
