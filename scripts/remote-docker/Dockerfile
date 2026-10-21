FROM rust:1-trixie

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-server netcat-openbsd lldb gdb tar \
 && rm -rf /var/lib/apt/lists/* \
 && if ! command -v lldb-dap >/dev/null; then ln -s "$(ls /usr/bin/lldb-dap-* | sort -V | tail -1)" /usr/local/bin/lldb-dap; fi \
 && rustup component add rust-src clippy rustfmt

RUN useradd --create-home --shell /bin/bash dev \
 && mkdir -p /work /etc/ssh/keys /run/sshd \
 && chown -R dev:dev /work /usr/local/cargo /usr/local/rustup \
 && rm -f /etc/ssh/ssh_host_* \
 && printf 'PATH=%s\nCARGO_HOME=%s\nRUSTUP_HOME=%s\n' "$PATH" "$CARGO_HOME" "$RUSTUP_HOME" > /etc/environment

COPY sshd_config /etc/ssh/sshd_config.d/ride.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

EXPOSE 22
WORKDIR /work
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
