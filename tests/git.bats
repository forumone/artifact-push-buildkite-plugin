#!/usr/bin/env bats

load "$BATS_PATH/load.bash"

load "../lib/util"
load "../lib/config"
load "../lib/git"

@test "validate-git-config" {
  run validate-git-config

  assert_success
}

@test "git-user (config)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_USER='Config User'

  run git-user

  assert_success
  assert_output "Config User"
}

@test "git-user (system)" {
  stub git \
    'config user.name : echo System User'

  run git-user

  assert_success
  assert_output "System User"

  unstub git
}

@test "git-email (config)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL="config@example.com"

  run git-email

  assert_success
  assert_output "config@example.com"
}

@test "git-email (system)" {
  stub git \
    'config user.email : echo system@example.com'

  run git-email

  assert_success
  assert_output "system@example.com"

  unstub git
}

@test "git-commit-message (generated)" {
  export BUILDKITE_ORGANIZATION_SLUG=example
  export BUILDKITE_PIPELINE_SLUG=a-project
  export BUILDKITE_BRANCH=master
  export BUILDKITE_BUILD_NUMBER=123

  run git-commit-message

  assert_success

  assert_line --partial "example"
  assert_line --partial "a-project"
  assert_line --partial "master"
  assert_line --partial "123"
}

@test "git-commit-message (overridden)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_MESSAGE="Perform a build"
  export BUILDKITE_ORGANIZATION_SLUG=example
  export BUILDKITE_PIPELINE_SLUG=a-project
  export BUILDKITE_BRANCH=master
  export BUILDKITE_BUILD_NUMBER=123

  run git-commit-message

  assert_success
  assert_output "Perform a build"
}
