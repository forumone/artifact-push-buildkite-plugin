# ABOUT THIS FILE
#
# This file contains small utility functions shared by multiple other library helpers.

shopt -s extglob

# Usage:
#   env-format KEY
#
# KEY: A full or partial configuration key name such as "foo-bar"
#
# Formats a key into Buildkite's serialized environment format: bad characters are
# replaced with underscores, and all text is capitalized. This allows users to write
# "foo-bar" and have it be formatted properly.
env-format() {
  # ${name//x/y} replaces all occurrences of the pattern x with y
  local key="${1//+([^a-zA-Z0-9])/_}"

  # ${name^^} capitalizes
  echo "${key^^}"
}

# Usage:
#   is-truthy VALUE
#
# VALUE: A string value to check
#
# Checks for things that look kinda like a true value (we're pretty lenient)
is-truthy() {
  [[ "$1" =~ ^1|on|yes|true$ ]]
}

# Usage:
#   is-verbose
#
# Determines if the verbose config is set.
is-verbose() {
  is-truthy "$(get-config verbose)"
}

# Usage:
#   verbose [MESSAGE...]
#
# MESSAGE: A message to output (works like echo)
#
# Wrapper for echo that only outputs if the verbose config option is set
verbose() {
  if is-verbose; then
    echo "$@"
  fi
}

# Usage:
#   error [MESSAGE...]
#
# MESSAGE: A message to output (works like echo)
#
# Reports an error to stderr
error() {
  echo ERROR: "$@" >&2
}

# Usage:
#   warn [MESSAGE...]
#
# MESSAGE: A message to output (works like echo)
#
# Reports a warning to stderr
warn() {
  echo WARNING: "$@" >&2
}

# Usage:
#   header [MESSAGE...]
#
# MESSAGE: A message to output (works like echo)
#
# Outputs a header
header() {
  echo '~~~ :git:' "$@"
}

# Usage:
#   fail-build
#
# Function to hard fail, opening any collapsed output
fail-build() {
  echo "^^^ +++"
  exit 1
}
