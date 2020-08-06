# ABOUT THIS FILE
#
# This file contains helper functions that help scaffold Git repositories. Inspiration has
# been drawn both from other batslib-style libraries (notably bats-file and bats-assert),
# but also from the Git test suite itself.

# Usage:
#   git_init [--bare]
#
# Options:
#   --bare: A bare Git repository, suitable for pushing to.
#
# Output:
#   STDOUT - path to the newly-initialized repository
#
# This function creates a new repository.
git_init() {
  local bare=

  local arg
  for arg in "$@"; do
    case "$arg" in
    --bare)
      bare=1
      ;;

    --*)
      echo "Unrecognized option '${arg}' passed to git_init" |
        batslib_decorate "ERROR: git_init" |
        fail
      return $?
      ;;

    *)
      echo "Too many arguments provided to git_init" |
        batslib_decorate "ERROR: git_init" |
        fail
      return $?
      ;;
    esac
  done

  local -r template="$BATS_TMPDIR/${BATS_TEST_FILENAME##*/}-$BATS_TEST_NUMBER.XXXXXXXXXX"

  local dir
  if ! dir="$(mktemp -d -- "$template" 2>&1)"; then
    echo "$dir" |
      batslib_decorate "ERROR: git_init" |
      fail
    return $?
  fi

  local output
  if ! output="$(git -C "$dir" init ${bare:+--bare} 2>&1)"; then
    echo "$output" |
      batslib_decorate "ERROR: git_init" |
      fail
    return $?
  fi

  echo -n "$dir"
}

# Usage:
#   git_clone REPO
#
# Arguments:
#   REPO: A repository directory
#
# This function clones a repository that was created by git_init. Used mainly in the case
# of interacting with a bare Git repository, since there is no active checkout to assert
# the contents of files.
git_clone() {
  if test $# -eq 0; then
    echo "Not enough arguments provided to git_clone" |
      batslib_decorate "ERROR: git_clone" |
      fail
    return $?
  elif test $# -gt 1; then
    echo "Too many arguments provided to git_clone" |
      batslib_decorate "ERROR: git_clone" |
      fail
    return $?
  fi

  local -r repo="$1"
  local -r template="$BATS_TMPDIR/${BATS_TEST_FILENAME##*/}-$BATS_TEST_NUMBER.XXXXXXXXXX"

  local dir
  if ! dir="$(mktemp -u -- "$template")"; then
    echo "$dir" |
      batslib_decorate "ERROR: git_clone" |
      fail
    return $?
  fi

  local output
  if ! output="$(git clone "$repo" "$dir" 2>&1)"; then
    echo "$output" |
      batslib_decorate "ERROR: git_clone" |
      fail
    return $?
  fi

  echo -n "$dir"
}

# Usage:
#   git_cleanup REPO
#
# Arguments:
#   REPO: A repository directory
#
# Globals:
#   BATSLIB_GIT_PRESERVE
#   BATSLIB_GIT_PRESERVE_ON_FAILURE
#
# This teardown function is used to clean up a repository directory.
git_cleanup() {
  if test $# -eq 0; then
    echo "A repository argument is required" |
      batslib_decorate "ERROR: git_cleanup" |
      fail
    return $?
  elif test $# -ge 2; then
    echo "Too many arguments provided to git_cleanup" |
      batslib_decorate "ERROR: git_cleanup" |
      fail
    return $?
  fi

  if test "$BATSLIB_GIT_PRESERVE" == 1; then
    return 0
  fi

  if test "$BATSLIB_GIT_PRESERVE_ON_FAILURE" == 1 && test "$BATS_TEST_COMPLETED" != 1; then
    return 0
  fi

  local -r path="$1"

  local output
  if ! output="$(rm -r -- "$path" 2>&1)"; then
    echo "$output" |
      batslib_decorate "ERROR: git_cleanup" |
      fail
    return $?
  fi
}

# Usage:
#   git_commit REPO FILE [--message MESSAGE] [--contents CONTENTS]
#
# Options
#   --message MESSAGE: A commit message. Defaults to "$FILE".
#   --contents CONTENTS: The file's contents. Defaults to "$FILE".
#
# Arguments:
#   REPO: A repository directory
#   FILE: A file to create in the repository.
#
# Creates a git commit in the specified REPO by creating or modifying FILE.
git_commit() {
  # Capture the arguments into an array to allow the interleaving of options and arguments.
  local -a args=()

  local message
  local contents

  while test $# -gt 0; do
    case "$1" in
    --message)
      shift
      message="$1"
      ;;

    --contents)
      shift
      contents="$1"
      ;;

    --)
      shift
      break
      ;;

    --*)
      echo "Unrecognized option '${1}' passed to git_commit" |
        batslib_decorate "ERROR: git_commit" |
        fail
      return $?
      ;;
    *)
      args+=("$1")
      ;;
    esac

    shift
  done

  args+=("$@")
  if test "${#args[@]}" -lt 2; then
    echo "Not enough arguments provided to git_commit" |
      batslib_decorate "ERROR: git_commit" |
      fail
    return $?
  elif test "${#args[@]}" -gt 2; then
    echo "Too many arguments provided to git_commit" |
      batslib_decorate "ERROR: git_commit" |
      fail
    return $?
  fi

  local -r repo="${args[0]}"
  local -r file="${args[1]}"
  : "${message:=$file}"
  : "${contents:=$file}"

  local output
  if ! output="$(mkdir -p -- "$(dirname "$repo/$file")" 2>&1)"; then
    echo "$output" |
      batslib_decorate "ERROR: git_commit" |
      fail
    return $?
  fi

  if ! output="$(echo -n "$contents" 2>&1 >"$repo/$file")"; then
    echo "$output" |
      batslib_decorate "ERROR: git_commit" |
      fail
    return $?
  fi

  if ! output="$(git -C "$repo" add -- "$file" 2>&1)"; then
    echo "$output" |
      batslib_decorate "ERROR: git_commit" |
      fail
    return $?
  fi

  if ! output="$(git -C "$repo" commit --message "$message" -- "$file" 2>&1)"; then
    echo "$output" |
      batslib_decorate "ERROR: git_commit" |
      fail
    return $?
  fi
}
