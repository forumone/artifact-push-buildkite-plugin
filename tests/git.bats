#!/usr/bin/env bats

load "$BATS_PATH/load.bash"

load "../lib/util"
load "../lib/config"
load "../lib/git"

@test "validate-git-config (system name; system email)" {
  stub git \
    'config user.name : echo System User' \
    'config user.email : echo system@example.com'

  run validate-git-config

  assert_success

  unstub git
}

@test "validate-git-config (system name; explicit email)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL='config@example.com'

  stub git \
    'config user.name : echo System User'

  run validate-git-config

  assert_success

  unstub git
}

@test "validate-git-config (system name; missing email)" {
  stub git \
    'config user.name : echo System User' \
    'config user.email : exit 1'

  run validate-git-config

  assert_failure
  refute_output --partial 'No Git user found'
  assert_output --partial 'No Git email found'

  unstub git
}

@test "validate-git-config (explicit name; system email)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME='Config User'

  stub git \
    'config user.email : echo Config User'

  run validate-git-config

  assert_success

  unstub git
}

@test "validate-git-config (explicit name; explicit email)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME='Config User'
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL='config@example.com'

  run validate-git-config

  assert_success
}

@test "validate-git-config (explicit name; missing email)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME='Config User'

  stub git \
    'config user.email : exit 1'

  run validate-git-config

  assert_failure
  refute_output --partial 'No Git user found'
  assert_output --partial 'No Git email found'

  unstub git
}

@test "validate-git-config (missing name; system email)" {
  stub git \
    'config user.name : exit 1' \
    'config user.email : echo system@example.com'

  run validate-git-config

  assert_failure
  assert_output --partial 'No Git user found'
  refute_output --partial 'No Git email found'

  unstub git
}

@test "validate-git-config (missing name; explicit email)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL='config@example.com'

  stub git \
    'config user.name : exit 1'

  run validate-git-config

  assert_failure
  assert_output --partial 'No Git user found'
  refute_output --partial 'No Git email found'

  unstub git
}

@test "validate-git-config (missing name; missing email)" {
  stub git \
    'config user.name : exit 1' \
    'config user.email : exit 1'

  run validate-git-config

  assert_failure
  assert_output --partial 'No Git user found'
  assert_output --partial 'No Git email found'

  unstub git
}

@test "git-user (config)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME='Config User'

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

# @test "git-user (git config fails)" {
#   stub git \
#     'config user.name : exit 1'

#   run git-user
#   assert_success
#   assert_output ""

#   unstub git
# }

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

# @test "git-email (git config fails)" {
#   stub git \
#     'config user.email : exit 1'

#   run git-email

#   assert_success
#   assert_output ""

#   unstub git
# }

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
