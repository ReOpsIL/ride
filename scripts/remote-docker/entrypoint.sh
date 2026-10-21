#!/bin/sh
set -eu

if [ ! -f /etc/ssh/keys/ssh_host_ed25519_key ]; then
  ssh-keygen -q -t ed25519 -N '' -f /etc/ssh/keys/ssh_host_ed25519_key
fi

if [ -z "${AUTHORIZED_KEY:-}" ]; then
  echo "AUTHORIZED_KEY is not set" >&2
  exit 1
fi

install -d -m 700 -o dev -g dev /home/dev/.ssh
printf '%s\n' "$AUTHORIZED_KEY" > /home/dev/.ssh/authorized_keys
chown dev:dev /home/dev/.ssh/authorized_keys
chmod 600 /home/dev/.ssh/authorized_keys

exec /usr/sbin/sshd -D -e
