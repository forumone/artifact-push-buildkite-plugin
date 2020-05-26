load test_helper

@test "git_cleanup(): BATSLIB_GIT_PRESERVE_ON_FAILURE=1 and test passed" {
  true
}

teardown() {
  local -ir BATSLIB_GIT_PRESERVE_ON_FAILURE=1
  git_cleanup "$TEST_REPO_DIR"
}
