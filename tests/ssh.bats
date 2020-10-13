#!/usr/bin/env bats

load "$BATS_PATH/load.bash"
load test_helper

load "../lib/util"
load "../lib/config"
load "../lib/ssh"

setup() {
  TEST_TMP_DIR="$(temp_make)"
}

teardown() {
  temp_del "$TEST_TMP_DIR"
}

@test "validate-ssh-config: empty config" {
  run validate-ssh-config
  assert_test_success
}

@test "validate-ssh-config: keyscan=HOST" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SSH_KEYSCAN=example.org

  run validate-ssh-config
  assert_test_success
}

@test "validate-ssh-config: keyscan=HOST:PORT" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SSH_KEYSCAN=example.org:123

  run validate-ssh-config
  assert_test_success
}

@test "validate-ssh-config: keyscan=HOST:PORT (port invalid)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SSH_KEYSCAN=example.org:port

  run validate-ssh-config

  assert_failure
  assert_line --partial "should be numeric"
}

@test "validate-ssh-config: keyscan syntax error" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SSH_KEYSCAN=example.org:1:2

  run validate-ssh-config

  assert_failure
  assert_line --partial "should be in HOST or HOST:PORT format"
}

@test "ssh-keyscan-host (keyscan=)" {
  run ssh-keyscan-host
  assert_test_success
}

@test "ssh-keyscan-host (keyscan=HOST)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SSH_KEYSCAN=example.org

  run ssh-keyscan-host

  assert_success
  assert_output "example.org"
}

@test "ssh-keyscan-host (keyscan=HOST:PORT)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SSH_KEYSCAN=example.org:123

  run ssh-keyscan-host

  assert_success
  assert_output "example.org"
}

@test "ssh-keyscan-port (keyscan=)" {
  run ssh-keyscan-port
  assert_test_success
}

@test "ssh-keyscan-port (keyscan=HOST)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SSH_KEYSCAN=example.org

  run ssh-keyscan-port
  assert_test_success
}

@test "ssh-keyscan-port (keyscan=HOST:PORT)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SSH_KEYSCAN=example.org:123

  run ssh-keyscan-port

  assert_success
  assert_output "123"
}

@test "ssh-perform-keyscan (keyscan=HOST)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SSH_KEYSCAN=example.org

  stub ssh-keyscan \
    'example.org : echo -n HOST KEY'

  run ssh-perform-keyscan "$TEST_TMP_DIR/known_hosts"

  assert_success
  assert_output --partial "example.org..."

  assert_contents_of_file "$TEST_TMP_DIR/known_hosts" "HOST KEY"

  unstub ssh-keyscan
}

@test "ssh-perform-keyscan (keyscan=HOST:PORT)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SSH_KEYSCAN=example.org:123

  stub ssh-keyscan \
    '-p 123 example.org : echo -n HOST+PORT KEY'

  run ssh-perform-keyscan "$TEST_TMP_DIR/known_hosts"

  assert_success
  assert_output --partial "example.org:123..."

  assert_contents_of_file "$TEST_TMP_DIR/known_hosts" "HOST+PORT KEY"

  unstub ssh-keyscan
}

@test "ssh-perform-keyscan (ssh-keyscan failure)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SSH_KEYSCAN=domain.invalid

  stub ssh-keyscan \
    'domain.invalid : echo "getaddrinfo: domain.invalid: Name or service not known" >/dev/stderr; exit 1'

  run ssh-perform-keyscan "$TEST_TMP_DIR/known_hosts"

  assert_failure
  assert_output --partial "Name or service not known"

  unstub ssh-keyscan
}
