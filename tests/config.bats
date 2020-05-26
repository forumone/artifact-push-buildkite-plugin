#!/usr/bin/env bats

load "$BATS_PATH/load.bash"

load "../lib/util"
load "../lib/config"

@test "config-key foo-bar" {
  run config-key foo-bar

  assert_output "BUILDKITE_PLUGIN_ARTIFACT_PUSH_FOO_BAR"
}

@test "config-key nested option" {
  run config-key nested option

  assert_output "BUILDKITE_PLUGIN_ARTIFACT_PUSH_NESTED_OPTION"
}

@test "get-config foo-bar" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_FOO_BAR=123

  run get-config foo-bar

  assert_output "123"
}

@test "get-config nested option" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_NESTED_OPTION=123

  run get-config nested option

  assert_output "123"
}

@test "get-config-with-default when set" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_OPTION=123

  run get-config-with-default 42 option

  assert_output "123"
}

@test "get-config-with-default when unset" {
  run get-config-with-default 42 option

  assert_output "42"
}

@test "validate-base-config (no options)" {
  run validate-base-config

  assert_failure
  assert_line --partial "source-directory"
  assert_line --partial "remote"
}

@test "validate-base-config (only source-directory)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=foo

  run validate-base-config

  assert_failure
  assert_line --partial "remote"

  refute_line --partial "source-directory"
}

@test "validate-base-config (only remote)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE=bar

  run validate-base-config

  assert_failure
  assert_line --partial "source-directory"

  refute_line --partial "remote"
}

@test "validate-base-config (both set)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=foo
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE=bar

  run validate-base-config

  assert_success
  assert_output ""
}
