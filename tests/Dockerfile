FROM bash:4.2

RUN apk add --no-cache ncurses jq curl git rsync

RUN curl -sSL https://github.com/bats-core/bats-core/archive/v1.2.0.tar.gz -o /tmp/bats-core.tgz \
  && tar -zxf /tmp/bats-core.tgz -C /tmp \
  && cd /tmp/bats-core-1.2.0 \
  && ./install.sh /usr/local \
  && cd / \
  && rm -rf bats-core-1.2.0

# Install bats-support
RUN mkdir -p /usr/local/lib/bats/bats-support \
    && curl -sSL https://github.com/ztombol/bats-support/archive/v0.3.0.tar.gz -o /tmp/bats-support.tgz \
    && tar -zxf /tmp/bats-support.tgz -C /usr/local/lib/bats/bats-support --strip 1 \
    && printf 'source "%s"\n' "/usr/local/lib/bats/bats-support/load.bash" >> /usr/local/lib/bats/load.bash \
    && rm -rf /tmp/bats-support.tgz

# Install bats-assert
RUN mkdir -p /usr/local/lib/bats/bats-assert \
    && curl -sSL https://github.com/ztombol/bats-assert/archive/v0.3.0.tar.gz -o /tmp/bats-assert.tgz \
    && tar -zxf /tmp/bats-assert.tgz -C /usr/local/lib/bats/bats-assert --strip 1 \
    && printf 'source "%s"\n' "/usr/local/lib/bats/bats-assert/load.bash" >> /usr/local/lib/bats/load.bash \
    && rm -rf /tmp/bats-assert.tgz

# Install lox's fork of bats-mock
RUN mkdir -p /usr/local/lib/bats/bats-mock \
    && curl -sSL https://github.com/lox/bats-mock/archive/v1.3.0.tar.gz -o /tmp/bats-mock.tgz \
    && tar -zxf /tmp/bats-mock.tgz -C /usr/local/lib/bats/bats-mock --strip 1 \
    && printf 'source "%s"\n' "/usr/local/lib/bats/bats-mock/stub.bash" >> /usr/local/lib/bats/load.bash \
    && rm -rf /tmp/bats-mock.tgz

# Install bats-file
RUN mkdir -p /usr/local/lib/bats/bats-file \
  && curl -sSL https://github.com/bats-core/bats-file/archive/v0.3.0.tar.gz -o /tmp/bats-file.tgz \
  && tar -xzf /tmp/bats-file.tgz -C /usr/local/lib/bats/bats-file --strip 1 \
  && printf 'source "%s"\n' "/usr/local/lib/bats/bats-file/load.bash" >> /usr/local/lib/bats/load.bash \
  && rm -rf /tmp/bats-file.tgz

# Make sure /bin/bash is available, as bats/bats only has it at
# /usr/local/bin/bash and many plugin hooks (and shellscripts in general) use
# `#!/bin/bash` as their shebang
RUN if [[ -e /bin/bash ]]; then echo "/bin/bash already exists"; exit 1; else ln -s /usr/local/bin/bash /bin/bash; fi

# Expose BATS_PATH so people can easily use load.bash
ENV BATS_PATH=/usr/local/lib/bats

WORKDIR /plugin

ENTRYPOINT []
CMD ["bats", "tests/"]
