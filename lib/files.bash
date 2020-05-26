# ABOUT THIS FILE
#
# File handling functions - these relate to temporary names and so on.

# Usage:
#   target-directory
#
# Creates a temporary directory based on the Buildkite environment.
target-directory() {
  mktemp --directory "$BUILDKITE_PIPELINE_SLUG-$BUILDKITE_BRANCH-$BUILDKITE_BUILD_NUMBER-tmp.XXXXXXXXXX"
}
