#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="${RIDE_REMOTE_NAME:-ride-rust}"
PORT="${RIDE_REMOTE_PORT:-2222}"
KEY="${RIDE_REMOTE_KEY:-$HOME/.ssh/ride_docker}"
IMAGE="ride-rust-remote"
KNOWN="$HOME/.ssh/known_hosts"

if [[ ! -f "$KEY" ]]; then
  ssh-keygen -q -t ed25519 -N '' -C "ride-docker" -f "$KEY"
fi

docker build -t "$IMAGE" "$HERE"
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" --hostname "$NAME" --restart unless-stopped \
  -p "127.0.0.1:$PORT:22" \
  --cap-add SYS_PTRACE --security-opt seccomp=unconfined \
  -e AUTHORIZED_KEY="$(cat "$KEY.pub")" \
  -v "$NAME-hostkeys:/etc/ssh/keys" \
  -v "$NAME-work:/work" \
  -v "$NAME-cargo:/usr/local/cargo/registry" \
  "$IMAGE" >/dev/null

for _ in $(seq 1 50); do
  docker exec "$NAME" test -f /etc/ssh/keys/ssh_host_ed25519_key.pub && break
  sleep 0.2
done
HOSTKEY="$(docker exec "$NAME" cat /etc/ssh/keys/ssh_host_ed25519_key.pub | cut -d' ' -f1,2)"

touch "$KNOWN"
for host in "127.0.0.1" "[127.0.0.1]:$PORT"; do
  ssh-keygen -R "$host" -f "$KNOWN" >/dev/null 2>&1 || true
  printf '%s %s\n' "$host" "$HOSTKEY" >> "$KNOWN"
done

ssh -i "$KEY" -p "$PORT" -o BatchMode=yes dev@127.0.0.1 \
  'cargo --version && command -v lldb-dap nc' </dev/null

cat <<INFO

Published port:  ssh -i $KEY -p $PORT dev@127.0.0.1
Docker preset:   container $NAME, user dev, identity $KEY, remote root /work/<project>
INFO
