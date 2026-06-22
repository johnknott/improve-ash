#!/usr/bin/env bash
set -euo pipefail

ensure_docker_access() {
  if docker info >/dev/null 2>&1; then
    return 0
  fi

  if command -v sg >/dev/null 2>&1 && sg docker -c 'docker info >/dev/null 2>&1'; then
    echo "error: this shell cannot access the Docker socket yet" >&2
    echo "hint: run 'newgrp docker' in this shell, or log out and back in" >&2
    exit 1
  fi

  echo "error: cannot access the Docker daemon via /var/run/docker.sock" >&2
  echo "hint: ensure docker.service is running and your user can access Docker" >&2
  exit 1
}

container_state() {
  docker inspect -f '{{if .State.Running}}{{if .State.Health}}{{.State.Health.Status}}{{else}}running{{end}}{{else}}stopped{{end}}' "$container" 2>/dev/null || true
}

container_project_dir() {
  docker inspect -f '{{index .Config.Labels "com.docker.compose.project.working_dir"}}' "$container" 2>/dev/null || true
}

ensure_docker_access

container="improve-ash-postgres"
timeout_seconds=60
existing_state="$(container_state)"
existing_project_dir="$(container_project_dir)"

if [ -n "$existing_state" ] && [ "$existing_project_dir" != "$PWD" ]; then
  echo "error: postgres container '$container' belongs to another compose project" >&2
  echo "found: ${existing_project_dir:-unknown}" >&2
  echo "want:  $PWD" >&2
  echo "hint: remove the stale container with: docker rm -f $container" >&2
  exit 1
fi

case "$existing_state" in
  healthy|running)
    exit 0
    ;;
  stopped)
    docker start "$container" >/dev/null
    ;;
  "")
    docker compose up -d postgres >/dev/null
    ;;
  unhealthy)
    echo "error: postgres container state is '$existing_state'" >&2
    echo "hint: inspect logs with: docker logs --tail=80 $container" >&2
    docker logs --tail=80 "$container" >&2 || true
    exit 1
    ;;
esac

for ((i = 0; i < timeout_seconds; i++)); do
  state="$(container_state)"
  case "$state" in
    healthy|running)
      exit 0
      ;;
    stopped|unhealthy)
      echo "error: postgres container state is '$state'" >&2
      echo "hint: inspect logs with: docker logs --tail=80 $container" >&2
      docker logs --tail=80 "$container" >&2 || true
      exit 1
      ;;
  esac
  sleep 1
done

echo "error: timed out waiting for postgres container to become healthy" >&2
echo "hint: inspect logs with: docker logs --tail=80 $container" >&2
exit 1
