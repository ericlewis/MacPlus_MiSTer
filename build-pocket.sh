#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if command -v quartus-vm >/dev/null 2>&1; then
  TOOL="$(command -v quartus-vm)"
elif [[ -x "$HOME/.local/bin/quartus-vm" ]]; then
  TOOL="$HOME/.local/bin/quartus-vm"
else
  echo "quartus-vm not found in PATH. Run the portable tool installer first." >&2
  exit 1
fi

cmd="build"
case "${1-}" in
  init-host|provision|init-repo|build|sweep-seeds|status|logs|stop|doctor|sync|pull|shell)
    cmd="$1"
    shift
    ;;
esac

exec "${TOOL}" "${cmd}" "${ROOT}" "$@"
