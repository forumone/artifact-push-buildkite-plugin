# ABOUT THIS FILE
#
# This file contains the functions needed to load plugin configuration from the
# environment.

# Usage:
#   config-key KEY [KEY...]
#
# KEY: One or more segments of a configuration option.
#
# This function takes a configuration option (or multiple segments of one) and formats it
# into Buildkite's exported configuration. The reason it takes multiple segments is that
# it is designed to mimic the YAML structure. Given this YAML plugin option:
#
#   - plugin: foo
#       option-1:
#         option-2: ~
#
# then the user can write "$(config-key option-1 option-2)" instead of having
# to mentally remap it to "$BUILDKITE_PLUGIN_ARTIFACT_PUSH_OPTION_1_OPTION_2".
config-key() {
  local name="BUILDKITE_PLUGIN_ARTIFACT_PUSH"

  for key in "$@"; do
    name="${name}_$(env-format "$key")"
  done

  echo -n "$name"
}

# Usage:
#   get-config KEY [KEY...]
#
# See config-key for definition of KEY.
#
# This reads out the named configuration key. If the value is not present in the
# environment, the empty string is returned.
get-config() {
  local key
  key="$(config-key "$@")"

  echo -n "${!key:-}"
}

# Usage:
#   get-config-with-default DEFAULT KEY [KEY...]
#
# See config-key for definition of KEY.
# DEFAULT: The default value to use instead of the empty string.
#
# This reads out the named configuration option. If the option is not present (or is
# empty), then DEFAULT is returned instead.
get-config-with-default() {
  local default="$1"
  shift

  local value
  value="$(get-config "$@")"

  echo "${value:-$default}"
}

# Usage:
#   validate-base-config
#
# A validation function to ensure that the source-directory and remote config options are
# present.
validate-base-config() {
  local failures=0

  local source
  source="$(get-config source-directory)"
  if test -z "$source"; then
    error "The configuration option source-directory was not found."
    failures=$((failures + 1))
  fi

  local remote
  remote="$(get-config remote)"
  if test -z "$remote"; then
    error "The configuration option remote was not found."
    failures=$((failures + 1))
  fi

  # exits 1 if any failures were encountered
  [ "$failures" -eq 0 ]
}
