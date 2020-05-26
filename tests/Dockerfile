FROM buildkite/plugin-tester:latest

RUN apk add --no-cache git rsync

RUN mkdir -p /usr/local/lib/bats/bats-file \
  && curl -sSL https://github.com/bats-core/bats-file/archive/v0.3.0.tar.gz -o /tmp/bats-file.tgz \
  && tar -xzf /tmp/bats-file.tgz -C /usr/local/lib/bats/bats-file --strip 1 \
  && printf 'source "%s"\n' "/usr/local/lib/bats/bats-file/load.bash" >> /usr/local/lib/bats/load.bash \
  && rm -rf /tmp/bats-file.tgz
