#!/usr/bin/env bash
set -euo pipefail

session_name="${1:-improve-ash-dev}"
layout_path="${2:-./scripts/zellij-dev.kdl}"

bootstrap_postgres() {
  printf "Ensuring local Postgres is running before starting dev services.\n"
  ./scripts/db-up-postgres.sh
}

session_line=""
if list_output="$(zellij list-sessions --no-formatting 2>/dev/null)"; then
  session_line="$(printf '%s\n' "$list_output" | awk -v name="$session_name" '$1 == name { print; exit }')"
fi

if [ -n "$session_line" ]; then
  if printf '%s' "$session_line" | grep -Fq "(EXITED"; then
    printf "Found dead zellij session '%s'. Deleting and starting fresh.\n" "$session_name"
    zellij delete-session "$session_name" >/dev/null 2>&1 || true
    bootstrap_postgres
    exec zellij --new-session-with-layout "$layout_path" --session "$session_name"
  fi

  printf "Attaching to existing zellij session '%s'.\n" "$session_name"
  exec zellij attach "$session_name"
fi

bootstrap_postgres
exec zellij --new-session-with-layout "$layout_path" --session "$session_name"
