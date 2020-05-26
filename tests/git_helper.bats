#!/usr/bin/env bats

load "$BATS_PATH/load.bash"
load git_helper
load test_helper

TEST_FIXTURE_ROOT="$BATS_TEST_DIRNAME/fixtures"

export GIT_AUTHOR_NAME="An Author"
export GIT_AUTHOR_EMAIL="author@test.bats"
export GIT_COMMITTER_NAME="A Committer"
export GIT_COMMITTER_EMAIL="committer@test.bats"

@test "git_init(): no arguments" {
  teardown() { rm -r "$TEST_REPO_DIR"; }

  TEST_REPO_DIR="$(git_init)"

  [[ -d "$TEST_REPO_DIR" ]]
  [[ -d "$TEST_REPO_DIR/.git" ]]
  [[ -d "$TEST_REPO_DIR/.git/refs/heads" ]]
}

@test "git_init(): '--bare'" {
  teardown() { rm -r "$TEST_REPO_DIR"; }

  TEST_REPO_DIR="$(git_init --bare)"

  [[ -d "$TEST_REPO_DIR" ]]
  [[ ! -d "$TEST_REPO_DIR/.git" ]]
  [[ -d "$TEST_REPO_DIR/refs/heads" ]]
}

@test "git_init(): too many arguments" {
  run git_init foo

  assert_test_failure \
    "ERROR: git_init" \
    "Too many arguments provided to git_init"
}

@test "git_init(): unrecognized option" {
  run git_init --oops

  assert_test_failure \
    "ERROR: git_init" \
    "Unrecognized option '--oops' passed to git_init"
}

@test "git_clone(): no arguments" {
  run git_clone
  assert_test_failure \
    "ERROR: git_clone" \
    "Not enough arguments provided to git_clone"
}

@test "git_clone(): too many arguments" {
  run git_clone one two
  assert_test_failure \
    "ERROR: git_clone" \
    "Too many arguments provided to git_clone"
}

@test "git_clone()" {
  teardown() { rm -r -- "$TEST_REPO_DIR"; rm -r -- "$TEST_CLONE_DIR"; }

  TEST_REPO_DIR="$(git_init --bare)"
  TEST_CLONE_DIR="$(git_clone "$TEST_REPO_DIR")"

  assert [[ -d "$TEST_CLONE_DIR" ]]
  assert [[ -d "$TEST_CLONE_DIR/.git" ]]
  assert [[ -d "$TEST_CLONE_DIR/.git/refs/heads" ]]

  run git -C "$TEST_CLONE_DIR" remote -v
  assert_success
  assert_line --partial "$TEST_REPO_DIR (fetch)"
  assert_line --partial "$TEST_REPO_DIR (push)"
}

@test "git_cleanup(): no arguments" {
  run git_cleanup

  assert_test_failure \
    "ERROR: git_cleanup" \
    "A repository argument is required"
}

@test "git_cleanup(): too many arguments" {
  run git_cleanup foo bar baz

  assert_test_failure \
    "ERROR: git_cleanup" \
    "Too many arguments provided to git_cleanup"
}

@test "git_cleanup(): non-existent dir" {
  run git_cleanup /invalid/path/to/repo

  assert_test_failure \
    "ERROR: git_cleanup" \
    "rm: can't remove '/invalid/path/to/repo': No such file or directory"
}

@test "git_cleanup(): respects BATSLIB_GIT_PRESERVE" {
  teardown() { rm -r -- "$TEST_REPO_DIR"; }

  TEST_REPO_DIR="$(git_init)"
  local -r BATSLIB_GIT_PRESERVE=1
  run git_cleanup "$TEST_REPO_DIR"

  assert_test_success
  [[ -d "$TEST_REPO_DIR" ]]
}

@test "git_cleanup(): BATSLIB_GIT_PRESERVE_ON_FAILURE=1 and test passed" {
  TEST_REPO_DIR="$(git_init)"
  export TEST_REPO_DIR

  run bats "$TEST_FIXTURE_ROOT/git_cleanup-pass.bats"

  [[ "$status" -eq 0 ]]
  [[ ! -d "$TEST_REPO_DIR" ]]
}

@test "git_cleanup(): BATSLIB_GIT_PRESERVE_ON_FAILURE=1 and test failed" {
  teardown() { rm -r -- "$TEST_REPO_DIR"; }

  TEST_REPO_DIR="$(git_init)"
  export TEST_REPO_DIR

  run bats "$TEST_FIXTURE_ROOT/git_cleanup-fail.bats"

  [[ "$status" -eq 1 ]]
  [[ -d "$TEST_REPO_DIR" ]]
}

@test "git_commit(): no arguments" {
  run git_commit
  assert_test_failure \
    "ERROR: git_commit" \
    "Not enough arguments provided to git_commit"
}

@test "git_commit(): only repo argument" {
  run git_commit /path/to/repo
  assert_test_failure \
    "ERROR: git_commit" \
    "Not enough arguments provided to git_commit"
}

@test "git_commit(): zero arguments" {
  run git_commit
  assert_test_failure \
    "ERROR: git_commit" \
    "Not enough arguments provided to git_commit"
}

@test "git_commit(): one argument" {
  run git_commit /path/to/repo
  assert_test_failure \
    "ERROR: git_commit" \
    "Not enough arguments provided to git_commit"
}

@test "git_commit(): too many arguments" {
  run git_commit /path/to/repo file contents overflow

  assert_test_failure \
    "ERROR: git_commit" \
    "Too many arguments provided to git_commit"
}

@test "git_commit(): unrecognized option" {
  run git_commit --unrecognized

  assert_test_failure \
    "ERROR: git_commit" \
    "Unrecognized option '--unrecognized' passed to git_commit"
}

@test "git_commit(): file" {
  teardown() { rm -r -- "$TEST_REPO_DIR"; }

  TEST_REPO_DIR="$(git_init)"

  run git_commit "$TEST_REPO_DIR" file
  assert_test_success

  assert_contents_of_file "$TEST_REPO_DIR/file" "file"

  run git -C "$TEST_REPO_DIR" log --format=%s
  assert_success
  assert_output "file"
}

@test "git_commit(): file+message" {
  teardown() { rm -r -- "$TEST_REPO_DIR"; }

  TEST_REPO_DIR="$(git_init)"

  run git_commit "$TEST_REPO_DIR" --message "message" file
  assert_test_success

  assert_contents_of_file "$TEST_REPO_DIR/file" "file"

  run git -C "$TEST_REPO_DIR" log --format=%s
  assert_success
  assert_output "message"
}

@test "git_commit(): file+contents" {
  teardown() { rm -r -- "$TEST_REPO_DIR"; }

  TEST_REPO_DIR="$(git_init)"

  run git_commit "$TEST_REPO_DIR" --contents "contents" file
  assert_test_success

  assert_contents_of_file "$TEST_REPO_DIR/file" "contents"

  run git -C "$TEST_REPO_DIR" log --format=%s
  assert_success
  assert_output "file"
}

@test "git_commit(): file+message+contents" {
  teardown() { rm -r -- "$TEST_REPO_DIR"; }

  TEST_REPO_DIR="$(git_init)"

  run git_commit "$TEST_REPO_DIR" file --message "message" --contents "contents"
  assert_test_success

  assert_contents_of_file "$TEST_REPO_DIR/file" "contents"

  run git -C "$TEST_REPO_DIR" log --format=%s
  assert_success
  assert_output "message"
}

@test "git_commit(): dir/file" {
  teardown() { rm -r -- "$TEST_REPO_DIR"; }

  TEST_REPO_DIR="$(git_init)"

  run git_commit "$TEST_REPO_DIR" dir/file
  assert_test_success

  assert_contents_of_file "$TEST_REPO_DIR/dir/file" "dir/file"
}

@test "git_commit(): '--' to separate options" {
  teardown() { rm -r -- "$TEST_REPO_DIR"; }

  TEST_REPO_DIR="$(git_init)"

  run git_commit "$TEST_REPO_DIR" -- --filename
  assert_test_success

  assert_contents_of_file "$TEST_REPO_DIR/--filename" "--filename"

  run git -C "$TEST_REPO_DIR" log --format=%s
  assert_success
  assert_output "--filename"
}
