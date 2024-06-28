#!/usr/bin/env bats

load "$BATS_PATH/load.bash"

load "../lib/util"
load "../lib/config"
load "../lib/branches"

@test "is-branch-required (no config)" {
  run is-branch-required

  assert_failure
  assert_output ""
}

@test "is-branch-required (explicit false)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REQUIRE_BRANCH=0

  run is-branch-required

  assert_failure
  assert_output ""
}

@test "is-branch-required (true)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REQUIRE_BRANCH=yes

  run is-branch-required

  assert_success
  assert_output ""
}

@test "build-branch-config (no config)" {
  run build-branch-config

  assert_success
  assert_output ""
}

@test "build-branch-config (overlapping matches, shorthand)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1=master

  run build-branch-config

  assert_failure
  assert_line --partial "already has a deployment target"
}

@test "build-branch-config (overlapping matches, longhand)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_TARGET=stable

  run build-branch-config

  assert_failure
  assert_line --partial "already has a deployment target"
}

@test "build-branch-config (missing target)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master

  run build-branch-config

  assert_failure
  assert_line --partial "has no target to deploy to"
}

@test "build-branch-config (shorthand, no overlap)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1=stable

  run build-branch-config

  assert_success
  assert_output ""
}

@test "build-branch-config (longhand, no overlap)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_MATCH=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_TARGET=stable

  run build-branch-config

  assert_success
  assert_output ""
}

@test "build-branch-config (shorthand+longhand, no overlap)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_MATCH=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_TARGET=stable

  run build-branch-config

  assert_success
  assert_output ""
}

# NB. The get-branch-target and get-branch-remote functions only work if the branch
# mapping has been built. Due to this fact, we use a slightly different structure for
# running these tests: we do assert_equal checks against the output of the function, which
# suffices for simple functions like this.

@test "get-branch-target (shorthand)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1=stable
  export BUILDKITE_BRANCH=master

  build-branch-config

  assert_equal "$(get-branch-target)" "master"
}

@test "get-branch-target (longhand)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_MATCH=live
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_TARGET=live
  export BUILDKITE_BRANCH=master

  build-branch-config

  assert_equal "$(get-branch-target)" "stable"
}

@test "get-branch-target (no targets)" {
  export BUILDKITE_BRANCH=master

  build-branch-config

  assert_equal "$(get-branch-target)" ""
}

@test "get-branch-target (shorthand, no match)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_BRANCH=stable

  build-branch-config

  assert_equal "$(get-branch-target)" ""
}

@test "get-branch-target (longhand, no match)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=live
  export BUILDKITE_BRANCH=master

  build-branch-config

  assert_equal "$(get-branch-target)" ""
}

@test "get-branch-remote (shorthand)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE=example.org
  export BUILDKITE_BRANCH=master

  build-branch-config

  assert_equal "$(get-branch-remote)" "example.org"
}

@test "get-branch-remote (longhand)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_MATCH=live
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_TARGET=live
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE=example.org
  export BUILDKITE_BRANCH=master

  build-branch-config

  assert_equal "$(get-branch-remote)" "example.org"
}

@test "get-branch-remote (longhand, override)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_REMOTE=example.com
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_MATCH=live
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_TARGET=live
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE=example.org
  export BUILDKITE_BRANCH=master

  build-branch-config

  assert_equal "$(get-branch-remote)" "example.com"
}

@test "get-branch-tag (shorthand)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE=example.org
  export BUILDKITE_BRANCH=master

  build-branch-config

  assert_equal "$(get-branch-tag)" ""
}

@test "get-branch-tag (longhand; no tag)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_MATCH=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_TARGET=stable
  export BUILDKITE_BRANCH=master

  build-branch-config

  assert_equal "$(get-branch-tag)" ""
}

@test "get-branch-tag (longhand; no match)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_MATCH=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_TARGET=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_TAG='release-$BUILDKITE_BUILD_NUMBER'
  export BUILDKITE_BRANCH=master

  build-branch-config

  assert_equal "$(get-branch-tag)" ""
}

@test "get-branch-tag (longhand; match)" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TAG='release-$BUILDKITE_BUILD_NUMBER'
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_MATCH=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_TARGET=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_1_TAG='deploy-$BUILDKITE_BUILD_NUMBER'
  export BUILDKITE_BRANCH=master

  build-branch-config

  assert_equal "$(get-branch-tag)" 'release-$BUILDKITE_BUILD_NUMBER'
}
