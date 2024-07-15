#!/usr/bin/env bats

load "$BATS_PATH/load.bash"
load git_helper
load test_helper

setup() {
  SOURCE_REPO="$(git_init)"
  REMOTE_REPO="$(git_init --bare)"
  REMOTE_CLONE="$(git_clone "$REMOTE_REPO")"

  export GIT_AUTHOR_NAME="An Author"
  export GIT_AUTHOR_EMAIL="author@test.bats"
  export GIT_COMMITTER_NAME="A Committer"
  export GIT_COMMITTER_EMAIL="comitter@test.bats"
}

teardown() {
  git_cleanup "$SOURCE_REPO"
  git_cleanup "$REMOTE_REPO"
  git_cleanup "$REMOTE_CLONE"
}

@test "hook: no changes" {
  stub buildkite-agent \
    'annotate --style=warning : true'

  plugin="$PWD"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo
  git_commit "$REMOTE_CLONE" bar
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  remote_head="$(cat "$REMOTE_REPO/refs/heads/master")"

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" foo
  git_commit "$SOURCE_REPO" bar

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  # Assertions:
  # 1. The plugin exited cleanly
  # 2. The user has been notified
  # 3. The remote repository has a new (empty) commit
  # 4. No new tags were created on the remote
  assert_success
  assert_line --partial "Git reports no changes."

  refute_contents_of_file "$REMOTE_REPO/refs/heads/master" "$remote_head"
  head="$(cat "$REMOTE_REPO/refs/heads/master")"

  run git -C "$REMOTE_REPO" show --raw --format=%H "$head"
  assert_success
  assert_output "$head"

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output ""

  unstub buildkite-agent
}

@test "hook: no changes (with tag)" {
  stub buildkite-agent \
    'annotate --style=warning : true'

  plugin="$PWD"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo
  git_commit "$REMOTE_CLONE" bar
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  remote_head="$(cat "$REMOTE_REPO/refs/heads/master")"

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" foo
  git_commit "$SOURCE_REPO" bar

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TAG='release-$BUILDKITE_BUILD_NUMBER'
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  # Assertions:
  # 1. The plugin exited cleanly
  # 2. The user has been notified
  # 3. The remote repository has a new (empty) commit
  # 4. The remote repository has a new tag named release-123 matching the new commit
  assert_success
  assert_line --partial "Git reports no changes."

  refute_contents_of_file "$REMOTE_REPO/refs/heads/master" "$remote_head"
  head="$(cat "$REMOTE_REPO/refs/heads/master")"

  run git -C "$REMOTE_REPO" show --raw --format=%H "$head"
  assert_success
  assert_output "$head"

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output "release-123"

  assert_contents_of_file "$REMOTE_REPO/refs/tags/release-123" "$head"

  unstub buildkite-agent
}

@test "hook: no changes + ignored paths" {
  stub buildkite-agent \
    'annotate --style=warning : true'

  plugin="$PWD"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo
  git_commit "$REMOTE_CLONE" bar
  git_commit "$REMOTE_CLONE" .gitignore --contents $'baz\n'
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  remote_head="$(cat "$REMOTE_REPO/refs/heads/master")"

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" .gitignore --contents $'baz\n'
  git_commit "$SOURCE_REPO" foo
  git_commit "$SOURCE_REPO" bar

  echo baz >"$SOURCE_REPO/baz"

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_VERBOSE=yes

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  # Assertions:
  # 1. The plugin exited cleanly
  # 2. The user has been notified
  # 3. The remote repository has a new (empty) commit
  # 4. No tags were created on the remote
  assert_success
  assert_line --partial "Git reports no changes."

  refute_contents_of_file "$REMOTE_REPO/refs/heads/master" "$remote_head"
  head="$(cat "$REMOTE_REPO/refs/heads/master")"

  run git -C "$REMOTE_REPO" show --raw --format=%H "$head"

  assert_success
  assert_output "$head"

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output ""

  unstub buildkite-agent
}

@test "hook: simple sync from root" {
  plugin="$PWD"

  # Git log format: commit hash (%H) followed by commit message (%s)
  format="%H %s"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo --message "REMOTE - add foo"
  git_commit "$REMOTE_CLONE" bar --message "REMOTE - add bar"
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  remote_log="$(git -C "$REMOTE_CLONE" log --format="$format")"

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" foo --contents "source foo" --message "SOURCE - update foo"
  source_foo_commit="$(git -C "$SOURCE_REPO" log --format="$format" --max-count=1)"

  git_commit "$SOURCE_REPO" bar --contents "source bar" --message "SOURCE - update bar"
  source_bar_commit="$(git -C "$SOURCE_REPO" log --format="$format" --max-count=1)"

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  assert_success

  # Assertions:
  # 1. The foo and bar files have been updated on the remote
  # 2. The remote's git log has not been corrupted or synchronized with the source:
  #    1. The original remote log still applies
  #    2. The commit that introduced foo on the source is not present in the remote logs
  #    3. The commit that introduced bar on the source is not present in the remote logs
  # 3. The most recent commit to the remote mentions the default commit message format
  # 4. The most recent commit was authored by the plugin's git user and email
  # 5. No tags were created on the remote
  run git -C "$REMOTE_CLONE" pull
  assert_contents_of_file "$REMOTE_CLONE/foo" "source foo"
  assert_contents_of_file "$REMOTE_CLONE/bar" "source bar"

  run git -C "$REMOTE_CLONE" log --format="$format"
  assert_success
  assert_equal "${#lines[@]}" 3 # foo + bar + rsync
  assert_output --partial "$remote_log"
  refute_line "$source_foo_commit"
  refute_line "$source_bar_commit"

  run git -C "$REMOTE_CLONE" log --format=%s --max-count=1
  assert_success
  assert_line --partial "bats/artifact-push"

  run git -C "$REMOTE_CLONE" log --format="%an <%ae>" --max-count=1
  assert_success
  assert_output "bats <bats@localhost.localdomain>"

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output ""
}

@test "hook: simple sync from root (with tag)" {
  plugin="$PWD"

  # Git log format: commit hash (%H) followed by commit message (%s)
  format="%H %s"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo --message "REMOTE - add foo"
  git_commit "$REMOTE_CLONE" bar --message "REMOTE - add bar"
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  remote_log="$(git -C "$REMOTE_CLONE" log --format="$format")"

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" foo --contents "source foo" --message "SOURCE - update foo"
  source_foo_commit="$(git -C "$SOURCE_REPO" log --format="$format" --max-count=1)"

  git_commit "$SOURCE_REPO" bar --contents "source bar" --message "SOURCE - update bar"
  source_bar_commit="$(git -C "$SOURCE_REPO" log --format="$format" --max-count=1)"

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TAG='release-$BUILDKITE_BUILD_NUMBER'
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  assert_success

  # Assertions:
  # 1. The foo and bar files have been updated on the remote
  # 2. The remote's git log has not been corrupted or synchronized with the source:
  #    1. The original remote log still applies
  #    2. The commit that introduced foo on the source is not present in the remote logs
  #    3. The commit that introduced bar on the source is not present in the remote logs
  # 3. The most recent commit to the remote mentions the default commit message format
  # 4. The most recent commit was authored by the plugin's git user and email
  # 5. The tag release-123 has the same commit as the new remote commit
  run git -C "$REMOTE_CLONE" pull
  assert_contents_of_file "$REMOTE_CLONE/foo" "source foo"
  assert_contents_of_file "$REMOTE_CLONE/bar" "source bar"

  run git -C "$REMOTE_CLONE" log --format="$format"
  assert_success
  assert_equal "${#lines[@]}" 3 # foo + bar + rsync
  assert_output --partial "$remote_log"
  refute_line "$source_foo_commit"
  refute_line "$source_bar_commit"

  run git -C "$REMOTE_CLONE" log --format=%s --max-count=1
  assert_success
  assert_line --partial "bats/artifact-push"

  run git -C "$REMOTE_CLONE" log --format="%an <%ae>" --max-count=1
  assert_success
  assert_output "bats <bats@localhost.localdomain>"

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output "release-123"

  head="$(cat "$REMOTE_REPO/refs/heads/master")"
  assert_contents_of_file "$REMOTE_REPO/refs/tags/release-123" "$head"
}



@test "hook: simple sync from root (with timestamp tag)" {
  plugin="$PWD"

  # Git log format: commit hash (%H) followed by commit message (%s)
  format="%H %s"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo --message "REMOTE - add foo"
  git_commit "$REMOTE_CLONE" bar --message "REMOTE - add bar"
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  remote_log="$(git -C "$REMOTE_CLONE" log --format="$format")"

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" foo --contents "source foo" --message "SOURCE - update foo"
  source_foo_commit="$(git -C "$SOURCE_REPO" log --format="$format" --max-count=1)"

  git_commit "$SOURCE_REPO" bar --contents "source bar" --message "SOURCE - update bar"
  source_bar_commit="$(git -C "$SOURCE_REPO" log --format="$format" --max-count=1)"

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TAG='release-$(echo 1234-56-78)'
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  assert_success

  # Assertions:
  # 1. The foo and bar files have been updated on the remote
  # 2. The remote's git log has not been corrupted or synchronized with the source:
  #    1. The original remote log still applies
  #    2. The commit that introduced foo on the source is not present in the remote logs
  #    3. The commit that introduced bar on the source is not present in the remote logs
  # 3. The most recent commit to the remote mentions the default commit message format
  # 4. The most recent commit was authored by the plugin's git user and email
  # 5. The tag release-123 has the same commit as the new remote commit
  run git -C "$REMOTE_CLONE" pull
  assert_contents_of_file "$REMOTE_CLONE/foo" "source foo"
  assert_contents_of_file "$REMOTE_CLONE/bar" "source bar"

  run git -C "$REMOTE_CLONE" log --format="$format"
  assert_success
  assert_equal "${#lines[@]}" 3 # foo + bar + rsync
  assert_output --partial "$remote_log"
  refute_line "$source_foo_commit"
  refute_line "$source_bar_commit"

  run git -C "$REMOTE_CLONE" log --format=%s --max-count=1
  assert_success
  assert_line --partial "bats/artifact-push"

  run git -C "$REMOTE_CLONE" log --format="%an <%ae>" --max-count=1
  assert_success
  assert_output "bats <bats@localhost.localdomain>"

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output "release-1234-56-78"

  head="$(cat "$REMOTE_REPO/refs/heads/master")"
  assert_contents_of_file "$REMOTE_REPO/refs/tags/release-1234-56-78" "$head"
}

@test "hook: simple sync from nested" {
  plugin="$PWD"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo --contents "remote foo"
  git_commit "$REMOTE_CLONE" bar --contents "remote bar"
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" nested/foo --contents "source foo"
  git_commit "$SOURCE_REPO" nested/bar --contents "source bar"
  git_commit "$SOURCE_REPO" baz

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=nested
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  assert_success

  # Assertions:
  # 1. The foo and bar files have been copied into the remote's root
  # 2. Neither the nested/ directory nor the baz file has been copied.
  # 3. The only contents of the remote are the foo and bar files
  # 4. No tags were created on the remote
  git -C "$REMOTE_CLONE" pull
  assert_contents_of_file "$REMOTE_CLONE/foo" "source foo"
  assert_contents_of_file "$REMOTE_CLONE/bar" "source bar"
  assert_file_not_exist "$REMOTE_CLONE/nested"
  assert_file_not_exist "$REMOTE_CLONE/baz"

  run ls "$REMOTE_CLONE"
  assert_success
  cat <<OUTPUT | assert_output
bar
foo
OUTPUT

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output ""
}

@test "hook: simple sync with deletions" {
  plugin="$PWD"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo
  git_commit "$REMOTE_CLONE" bar
  git_commit "$REMOTE_CLONE" baz
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" foo

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  assert_success

  # Assertions:
  # 1. The file "foo" is untouched (same contents)
  # 2. The files "bar" and "baz" have been deleted from the remote
  # 3. No tags were created on the remote
  git -C "$REMOTE_CLONE" pull
  assert_contents_of_file "$REMOTE_CLONE/foo" foo
  assert_file_not_exist "$REMOTE_CLONE/bar"
  assert_file_not_exist "$REMOTE_CLONE/baz"

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output ""
}

@test "hook: simple sync with additions" {
  plugin="$PWD"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" foo
  git_commit "$SOURCE_REPO" bar
  git_commit "$SOURCE_REPO" baz

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  assert_success

  # Assertions:
  # 1. All three of foo, bar, and baz have been copied over to the remote
  # 2. No tags were created on the remote
  git -C "$REMOTE_CLONE" pull
  assert_contents_of_file "$REMOTE_CLONE/foo" foo
  assert_contents_of_file "$REMOTE_CLONE/bar" bar
  assert_contents_of_file "$REMOTE_CLONE/baz" baz

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output ""
}

@test "hook: sync master to stable" {
  plugin="$PWD"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo --contents "master foo"
  git_commit "$REMOTE_CLONE" baz --contents "master baz"
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  master_ref="$(cat "$REMOTE_REPO/refs/heads/master")"

  git -C "$REMOTE_CLONE" checkout -b stable
  git_commit "$REMOTE_CLONE" foo --contents "stable foo"
  git_commit "$REMOTE_CLONE" bar --contents "stable bar"
  git -C "$REMOTE_CLONE" push --set-upstream origin stable

  stable_ref="$(cat "$REMOTE_REPO/refs/heads/stable")"

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" foo --contents "source foo"
  git_commit "$SOURCE_REPO" bar --contents "source bar"

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  assert_success

  # Assertions:
  # 1. The remote's master branch has not been updated (refs/heads/<branch> = most recent commit ID)
  # 2. The remote's stable branch _has_ been updated
  # 3. On stable, the foo and bar files have been updated
  # 4. On master, no file has been touched
  # 5. No tags were created on the remote
  assert_contents_of_file "$REMOTE_REPO/refs/heads/master" "$master_ref"
  refute_contents_of_file "$REMOTE_REPO/refs/heads/stable" "$stable_ref"

  git -C "$REMOTE_CLONE" pull
  assert_contents_of_file "$REMOTE_CLONE/foo" "source foo"
  assert_contents_of_file "$REMOTE_CLONE/bar" "source bar"

  git -C "$REMOTE_CLONE" checkout master
  git -C "$REMOTE_CLONE" pull

  assert_contents_of_file "$REMOTE_CLONE/foo" "master foo"
  assert_file_not_exist "$REMOTE_CLONE/bar"
  assert_contents_of_file "$REMOTE_CLONE/baz" "master baz"

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output ""
}

@test "hook: sync master to stable (with tag)" {
  plugin="$PWD"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo --contents "master foo"
  git_commit "$REMOTE_CLONE" baz --contents "master baz"
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  master_ref="$(cat "$REMOTE_REPO/refs/heads/master")"

  git -C "$REMOTE_CLONE" checkout -b stable
  git_commit "$REMOTE_CLONE" foo --contents "stable foo"
  git_commit "$REMOTE_CLONE" bar --contents "stable bar"
  git -C "$REMOTE_CLONE" push --set-upstream origin stable

  stable_ref="$(cat "$REMOTE_REPO/refs/heads/stable")"

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" foo --contents "source foo"
  git_commit "$SOURCE_REPO" bar --contents "source bar"

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TAG='release-$BUILDKITE_BUILD_NUMBER'
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  assert_success

  # Assertions:
  # 1. The remote's master branch has not been updated (refs/heads/<branch> = most recent commit ID)
  # 2. The remote's stable branch _has_ been updated
  # 3. On stable, the foo and bar files have been updated
  # 4. On master, no file has been touched
  # 5. The tag release-123 has the most recent commit to stable
  assert_contents_of_file "$REMOTE_REPO/refs/heads/master" "$master_ref"
  refute_contents_of_file "$REMOTE_REPO/refs/heads/stable" "$stable_ref"

  git -C "$REMOTE_CLONE" pull
  assert_contents_of_file "$REMOTE_CLONE/foo" "source foo"
  assert_contents_of_file "$REMOTE_CLONE/bar" "source bar"

  git -C "$REMOTE_CLONE" checkout master
  git -C "$REMOTE_CLONE" pull

  assert_contents_of_file "$REMOTE_CLONE/foo" "master foo"
  assert_file_not_exist "$REMOTE_CLONE/bar"
  assert_contents_of_file "$REMOTE_CLONE/baz" "master baz"

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output "release-123"

  head="$(cat "$REMOTE_REPO/refs/heads/stable")"
  assert_contents_of_file "$REMOTE_REPO/refs/tags/release-123" "$head"
}

@test "hook: separate remotes" {
  teardown() {
    git_cleanup "$SOURCE_REPO"
    git_cleanup "$REMOTE_REPO"
    git_cleanup "$REMOTE_CLONE"
    git_cleanup "$PRISTINE_REPO"
  }

  plugin="$PWD"

  PRISTINE_REPO="$(git_init --bare)"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo
  git_commit "$REMOTE_CLONE" bar
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" foo --contents "new foo"
  git_commit "$SOURCE_REPO" bar --contents "new bar"

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$PRISTINE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  assert_success

  # Assertions:
  # 1. The bare repo in $PRISTINE_REPO has no new objects or branches
  # 2. The remote repository was updated properly
  # 3. No tags were created on the remote
  assert_file_not_exist "$PRISTINE_REPO/refs/heads/master"
  run ls "$PRISTINE_REPO/refs/heads"
  assert_success
  assert_output ""

  git -C "$REMOTE_CLONE" pull
  assert_contents_of_file "$REMOTE_CLONE/foo" "new foo"
  assert_contents_of_file "$REMOTE_CLONE/bar" "new bar"

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output ""
}

@test "hook: separate remotes (with tag)" {
  teardown() {
    git_cleanup "$SOURCE_REPO"
    git_cleanup "$REMOTE_REPO"
    git_cleanup "$REMOTE_CLONE"
    git_cleanup "$PRISTINE_REPO"
  }

  plugin="$PWD"

  PRISTINE_REPO="$(git_init --bare)"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo
  git_commit "$REMOTE_CLONE" bar
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" foo --contents "new foo"
  git_commit "$SOURCE_REPO" bar --contents "new bar"

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$PRISTINE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TAG='release-$BUILDKITE_BUILD_NUMBER'
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  assert_success

  # Assertions:
  # 1. The bare repo in $PRISTINE_REPO has no new objects or branches
  # 2. The remote repository was updated properly
  # 3. No release-123 tag was created for the pristine repo
  # 4. The remote repository's release-123 tag matches the pushed commit
  assert_file_not_exist "$PRISTINE_REPO/refs/heads/master"
  run ls "$PRISTINE_REPO/refs/heads"
  assert_success
  assert_output ""

  git -C "$REMOTE_CLONE" pull
  assert_contents_of_file "$REMOTE_CLONE/foo" "new foo"
  assert_contents_of_file "$REMOTE_CLONE/bar" "new bar"

  run ls "$PRISTINE_REPO/refs/tags"
  assert_success
  assert_output ""

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output "release-123"

  head="$(cat "$REMOTE_REPO/refs/heads/master")"
  assert_contents_of_file "$REMOTE_REPO/refs/tags/release-123" "$head"
}

@test "hook: separate remotes with branch override" {
  teardown() {
    git_cleanup "$SOURCE_REPO"
    git_cleanup "$REMOTE_REPO"
    git_cleanup "$REMOTE_CLONE"
    git_cleanup "$PRISTINE_REPO"
  }

  plugin="$PWD"

  PRISTINE_REPO="$(git_init --bare)"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo --contents "master foo"
  git_commit "$REMOTE_CLONE" bar --contents "master bar"
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  git -C "$REMOTE_CLONE" checkout -b stable
  git_commit "$REMOTE_CLONE" foo --contents "stable foo"
  git_commit "$REMOTE_CLONE" bar --contents "stable bar"
  git -C "$REMOTE_CLONE" push --set-upstream origin stable

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" foo --contents "new foo"
  git_commit "$SOURCE_REPO" bar --contents "new bar"

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$PRISTINE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  assert_success

  # Assertions:
  # 1. The bare repo in $PRISTINE_REPO has no new objects or branches
  # 2. The remote repository was updated properly
  # 3. The master branch has not been perturbed on the remote
  # 4. No tags were created
  assert_file_not_exist "$PRISTINE_REPO/refs/heads/master"
  assert_file_not_exist "$PRISTINE_REPO/refs/heads/stable"
  run ls "$PRISTINE_REPO/refs/heads"
  assert_success
  assert_output ""

  git -C "$REMOTE_CLONE" pull
  assert_contents_of_file "$REMOTE_CLONE/foo" "new foo"
  assert_contents_of_file "$REMOTE_CLONE/bar" "new bar"

  git -C "$REMOTE_CLONE" checkout master
  run git -C "$REMOTE_CLONE" pull
  assert_output "Already up to date."
  assert_contents_of_file "$REMOTE_CLONE/foo" "master foo"
  assert_contents_of_file "$REMOTE_CLONE/bar" "master bar"

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output ""
}

@test "hook: separate remotes with branch override (with tag)" {
  teardown() {
    git_cleanup "$SOURCE_REPO"
    git_cleanup "$REMOTE_REPO"
    git_cleanup "$REMOTE_CLONE"
    git_cleanup "$PRISTINE_REPO"
  }

  plugin="$PWD"

  PRISTINE_REPO="$(git_init --bare)"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo --contents "master foo"
  git_commit "$REMOTE_CLONE" bar --contents "master bar"
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  git -C "$REMOTE_CLONE" checkout -b stable
  git_commit "$REMOTE_CLONE" foo --contents "stable foo"
  git_commit "$REMOTE_CLONE" bar --contents "stable bar"
  git -C "$REMOTE_CLONE" push --set-upstream origin stable

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" foo --contents "new foo"
  git_commit "$SOURCE_REPO" bar --contents "new bar"

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$PRISTINE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_MATCH=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TARGET=stable
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0_TAG='release-$BUILDKITE_BUILD_NUMBER'
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  assert_success

  # Assertions:
  # 1. The bare repo in $PRISTINE_REPO has no new objects or branches
  # 2. The remote repository was updated properly
  # 3. The master branch has not been perturbed on the remote
  # 4. The release-123 tag has the same commit as the new push to stable
  assert_file_not_exist "$PRISTINE_REPO/refs/heads/master"
  assert_file_not_exist "$PRISTINE_REPO/refs/heads/stable"
  run ls "$PRISTINE_REPO/refs/heads"
  assert_success
  assert_output ""

  git -C "$REMOTE_CLONE" pull
  assert_contents_of_file "$REMOTE_CLONE/foo" "new foo"
  assert_contents_of_file "$REMOTE_CLONE/bar" "new bar"

  git -C "$REMOTE_CLONE" checkout master
  run git -C "$REMOTE_CLONE" pull
  assert_output "Already up to date."
  assert_contents_of_file "$REMOTE_CLONE/foo" "master foo"
  assert_contents_of_file "$REMOTE_CLONE/bar" "master bar"

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output "release-123"

  head="$(cat "$REMOTE_REPO/refs/heads/stable")"
  assert_contents_of_file "$REMOTE_REPO/refs/tags/release-123" "$head"
}

@test "hook: custom commit message" {
  plugin="$PWD"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" foo --contents "new foo"

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_MESSAGE="Custom commit"

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  assert_success

  # Assertions:
  # 1. Our commit message appears in the remote's log
  # 2. No tags were created
  git -C "$REMOTE_CLONE" pull
  run git -C "$REMOTE_CLONE" log --format="%s"
  cat <<OUTPUT | assert_output
Custom commit
foo
OUTPUT

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output ""
}

@test "hook: ignore list" {
  plugin="$PWD"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo
  git_commit "$REMOTE_CLONE" precious
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" foo --contents "new foo"

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_FILES_IGNORE_0=precious
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_MESSAGE="Custom commit"

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  assert_success

  # Assertions:
  # 1. The file "foo" was updated on the remote
  # 2. The file "precious" was not deleted despite not existing in the source
  # 3. No tags were created on the remote
  git -C "$REMOTE_CLONE" pull
  assert_contents_of_file "$REMOTE_CLONE/foo" "new foo"
  assert_contents_of_file "$REMOTE_CLONE/precious" "precious"

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output ""
}

@test "hook: force-add list" {
  plugin="$PWD"

  git -C "$REMOTE_CLONE" checkout -b master
  git_commit "$REMOTE_CLONE" foo
  git -C "$REMOTE_CLONE" push --set-upstream origin master

  git -C "$SOURCE_REPO" checkout -b master
  git_commit "$SOURCE_REPO" .gitignore --contents $'artifact\ncruft\n'
  git_commit "$SOURCE_REPO" foo --contents "source foo"
  git_commit "$SOURCE_REPO" bar --contents "source bar"

  # Simulate build artifacts
  echo -n "artifact" >"$SOURCE_REPO/artifact"
  echo -n "cruft" >"$SOURCE_REPO/cruft"

  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_FILES_FORCE_ADD_0=artifact
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_MESSAGE="Custom commit"

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master

  pushd "$SOURCE_REPO"
  run "$plugin/hooks/post-command"
  popd

  assert_success

  # Assertions:
  # 1. The files "foo" and "bar" were copied over
  # 2. The artifact file was force-added and copied over
  # 3. The cruft file was not copied over
  # 4. No tags were created on the remote
  git -C "$REMOTE_CLONE" pull
  assert_contents_of_file "$REMOTE_CLONE/foo" "source foo"
  assert_contents_of_file "$REMOTE_CLONE/bar" "source bar"
  assert_contents_of_file "$REMOTE_CLONE/artifact" "artifact"
  assert_file_not_exist "$REMOTE_CLONE/cruft"

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output ""
}

@test "hook: branches=[]" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master
  export BUILDKITE_BRANCH=master

  run "hooks/post-command"

  # Assertions:
  # 1. The command soft failed with information about no branches
  # 2. No changes were made to the remote repository
  assert_success
  assert_line --partial "No branch mappings"
  assert_line --partial "no deployment destination"
  refute_line --partial "branch to deploy to"
  refute_line --partial "Branch mappings:"

  run ls "$REMOTE_REPO/refs/heads"
  assert_success
  assert_output ""

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output ""
}

@test "hook: branches=[] and require-branch" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REQUIRE_BRANCH=yes

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master
  export BUILDKITE_BRANCH=master

  run "hooks/post-command"

  # Assertions:
  # 1. The plugin failed
  # 2. No objects or tags were created
  assert_failure
  assert_line --partial "No branch mappings"
  assert_line --partial "branch to deploy to"
  assert_line --partial "Branch mappings:"

  run ls "$REMOTE_REPO/refs/heads"
  assert_success
  assert_output ""

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output ""
}

@test "hook: no matching branch" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master
  export BUILDKITE_BRANCH=stable

  run "hooks/post-command"

  # Assertions:
  # 1. The plugin soft failed
  # 2. No activity occurred on the remote
  assert_success
  assert_line --partial "no deployment destination"
  refute_line --partial "branch to deploy to"
  refute_line --partial "Branch mappings:"

  run ls "$REMOTE_REPO/refs/heads"
  assert_success
  assert_output ""

  run ls "$REMOTE_REPO/refs/tags"
  assert_success
  assert_output ""
}

@test "hook: no matching branch and require-branch" {
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REMOTE="file://$REMOTE_REPO"
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_SOURCE_DIRECTORY=.
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_BRANCHES_0=master
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_REQUIRE_BRANCH=yes
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_NAME=bats
  export BUILDKITE_PLUGIN_ARTIFACT_PUSH_GIT_EMAIL=bats@localhost.localdomain

  export BUILDKITE_ORGANIZATION_SLUG=bats
  export BUILDKITE_PIPELINE_SLUG=artifact-push
  export BUILDKITE_BUILD_NUMBER=123
  export BUILDKITE_BRANCH=master
  export BUILDKITE_BRANCH=stable

  run "hooks/post-command"

  # Assertions:
  # 1. The plugin failed and let the user know what the mappings are
  # 2. No activity has occured on the remote
  assert_failure
  assert_line --partial "Current branch: stable"
  assert_line --partial "  * master: Deploys to branch master on remote file://$REMOTE_REPO"

  run ls "$REMOTE_REPO/refs/heads"
  assert_success
  assert_output ""

  run ls "$REMOTE_REPO/refs/heads"
  assert_success
  assert_output ""
}

@test "hook: exit status <> 0" {
  export BUILDKITE_COMMAND_EXIT_STATUS=1

  git_commit "$SOURCE_REPO" foo

  run "hooks/post-command"

  # Assertions:
  # 1. The plugin notes that it refuses to run
  # 2. The remote repository is untouched
  assert_success
  assert_line --partial "due to failed build"

  run ls "$REMOTE_REPO/refs/heads"
  assert_success
  assert_output ""
}
