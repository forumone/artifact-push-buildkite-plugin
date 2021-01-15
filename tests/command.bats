load "$BATS_PATH/load.bash"

@test "command hook: BUILDKITE_COMMAND is set" {
  export BUILDKITE_COMMAND="echo hello world"

  run "$PWD/hooks/command"

  assert_success
  assert_output "hello world"
}

@test "command hook: BUILDKITE_COMMAND is not set" {
  run "$PWD/hooks/command"

  assert_success
  assert_output ""
}
