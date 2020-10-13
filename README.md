# Artifact Push Buildkite Plugin
[![Build status](https://badge.buildkite.com/b00e731dfca9d91754114dc2e6d31c13a77afe24779dbdf6f2.svg?branch=master)](https://buildkite.com/forum-one/artifact-push-buildkite-plugin)

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) to push build artifacts to Git repositories, primarily intended for use with Git-based deployments to hosting providers such as Pantheon and Acquia.

The plugin works in a few phases:

1. First, it performs a shallow clone of the remote repository to a temporary directory.
2. Second, it uses `rsync` to copy files from the build directory to the remote directory.
3. Third, it adds all changed files to a new commit and pushes to the remote.

By design, this plugin intentionally forgets the project's history: it attempts to act as if it were doing work directly on the remote repository instead of attempting to reconcile two divergent Git histories.

## Example

This is the simplest use of the plugin. Whenever the `master` branch is built, it pushes to the remote's `master` branch.

```yaml
steps:
  - plugins:
      - forumone/artifact-push#v0.2.0:
          source-directory: .
          remote: git@example.com/remote.git
          branches:
            - master
```

The `branches` option is fairly flexible. The simplest form, shown above, just uses a string to indicate that the `master` branch should be used for both the project and the remote.

There is a long-hand form that can be used to change this mapping logic. For example, this pushes the project's `master` branch to the remote's `develop` branch:

```yaml
steps:
  - plugins:
      - forumone/artifact-push#v0.2.0:
          source-directory: services/drupal/web
          remote: git@example.com/remote.git
          branches:
            - match: master # project branch
              target: develop # remote branch
```

Finally, the remote can be changed on a per-branch basis in case there is a separate remote repository needed. This is the case with, for example, WP Engine's hosting environment.

```yaml
steps:
  - plugins:
      - forumone/artifact-push#v0.2.0:
          source-directory: services/drupal/web
          remote: git@example.com/remote/development.git
          branches:
            - match: master
              target: master
            - match: stable
              target: master
              remote: git@example.com/remote/staging.git
```

If you need to perform an SSH keyscan to obtain `known_hosts` keys, use the `keyscan` option. This is useful if you are using ephemeral agents and/or are pushing to trusted hosts.

```yaml
steps:
  - plugins:
      - forumone/artifact-push#v0.2.0:
          source-directory: services/drupal/web
          remote: git@example.com/remote.git
          branches:
            - master

          ssh:
            # Use example.com:123 for a non-standard SSH port
            keyscan: example.com
```

When working with a source project, you generally will need to override your project's `.gitignore` to commit files such as compiled CSS or bundled scripts. The `files` option accepts a list of files to `force-add` with Git prior to pushing artifacts. Each line corresponds roughly to `git add -f $FILE`.

```yaml
steps:
  - plugins:
      - forumone/artifact-push#v0.2.0:
          source-directory: .
          remote: git@example.com/remote.git
          branches:
            - master

          files:
            force-add:
              - generated-css
              - generated-js
```

Similarly, if the remote tracks files that your project ignores, use the `ignore` option under `files` to prevent `rsync` from deleting them.

```yaml
steps:
  - plugins:
      - forumone/artifact-push#v0.2.0:
          source-directory: .
          remote: git@example.com/remote.git
          branches:
            - master

          files:
            ignore:
              - remote-only-file
```

The Git behavior can be overridden. The plugin accepts options to override the Git username, email address, and commit message. By default, it uses the Buildkite agent's Git identity and generates a commit message based on the pipeline slug, branch, and build number.

```yaml
steps:
  - plugins:
      - forumone/artifact-push#v0.2.0:
          source-directory: .
          remote: git@example.com/remote.git
          branches:
            - master

          # Git commit message
          message: "Commit $BUILDKITE_BUILD_NUMBER"

          git:
            name: Committer Name
            email: support@example.org
```

## Options

### `source-directory`

A directory inside the built project. Use `.` if you intend to push the entire project to your remote, and a name (such as `build`) if you only intend to sync a portion of the project.

### `remote`

The remote to push artifacts to. This can be any format that Git accepts as a remote name, but generally you probably want a notation like `git@github.com:<project>` or similar to use the Git+SSH protocol.

### `branches`

A list of configuration entries instructing the plugin how to perform its push.

There are two syntaxes for branches: string and object. A simple string is shorthand to indicate that the source and target branches are the same. That is, the string `master` means "when building `master` on Buildkite, push to the remote's `master` branch".

If using an object, there are three options:

- `match`: The name of the project branch (what Buildkite is building)
- `target`: The branch on the remote to push to
- `remote` (optional): Override the default remote with this one.

The `remote` option is useful when pushing to hosting providers that use separate repositories per environment. Thus, you can write `remote: example.com/staging.git` when pushing the staging branch, and so on.

### `require-branch` (optional)

If the plugin cannot determine a branch to push to (for example, it's run during the build of a feature branch), then it simply exits cleanly. Set `require-branch` to `true` if you would like it instead to fail the build. This is useful if you are limiting the plugin by other means (such as Buildkite's `branches` or `if` configuration) and want to make sure the plugin configuration is in sync.

### `files` (optional)

This controls how files are handled by the `rsync` and `git add` process. There are two lists of files: the ignore and force add lists.

#### `ignore` (optional)

This list is for protecting remote files from being updated or deleted. For example, Pantheon git repositories include a file called `pantheon.upstream.yml`, which is the information Pantheon needs to find a site's upstream. Deleting this file can cause serious repercussions.

Each entry is resolved inside the remote repository's checkout. For example, if the remote has a file called `secrets.txt` in the repository, write `secrets.txt` even if your `source-directory` is a subdirectory of your project.

#### `force-add` (optional)

This list is for force-adding built assets (that is, ignoring any `.gitignore` rules that might be in place). For example, if your theme's CSS is built from Sass files, then you would typically have the CSS directory in your `.gitignore` file.

As with the ignore list above, entries in this list are resolved relative to the remote repository's checkout. This means that if you are pushing a subdirectory of your project, ignore that subdirectory name when adding entries to this list. For example, if you set the `source-directory` option to `site`, then to force-add `site/css` you would simply write `css`.

### `git` (optional)

These options control the Git commit authoring process.

#### `name` (optional)

Sets the Git committer name to the specified value. By default, this is the value of `git user.name` as read from the Buildkite agent.

#### `email` (optional)

Sets the Git committer email to the specified value. By default, this is the value of `git config user.email`.

### `message` (optional)

Overrides the Git commit message. By default, the commit message is derived from the pipeline slug, current branch, and build number.

### `ssh` (optional)

Options controlling the behavior of SSH before the plugin performs any Git operations on its own.

#### `keyscan` (optional)

In some environments (such as Buildkite's Elastic CI Stack), agents may not have a trusted `known_hosts` file. In that case, this option can be used to obtain a host's SSH keys before performing a clone.

This should only be used if you trust the remote repository endpoint. When used incorrectly, this opens you up for man-in-the-middle attacks.

This option accepts two syntaxes:

* `HOST` requests a keyscan of HOST using the default SSH port.
* `HOST:PORT` - requests a keyscan of HOST using the specified PORT.
