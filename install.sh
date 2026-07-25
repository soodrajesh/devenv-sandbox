#!/usr/bin/env bash
set -euo pipefail

DEVENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_LINK="/usr/local/bin/devenv"

echo "devenv: installing from ${DEVENV_DIR}"

if ! command -v docker >/dev/null 2>&1; then
    echo "error: docker is not installed or not on PATH. Install Docker Desktop first: https://www.docker.com/products/docker-desktop/" >&2
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "error: Docker daemon is not running. Start Docker Desktop and re-run this script." >&2
    exit 1
fi

chmod +x "${DEVENV_DIR}/devenv"

if [[ -w "$(dirname "${BIN_LINK}")" ]]; then
    ln -sf "${DEVENV_DIR}/devenv" "${BIN_LINK}"
    echo "devenv: symlinked ${BIN_LINK} -> ${DEVENV_DIR}/devenv"
else
    echo "devenv: no write access to /usr/local/bin, symlinking with sudo"
    sudo ln -sf "${DEVENV_DIR}/devenv" "${BIN_LINK}"
fi

echo "devenv: building image (this can take a few minutes on first run)"
"${DEVENV_DIR}/devenv" build

echo ""
echo "devenv: install complete."
echo "  Run 'devenv up' from any project directory to start a sandbox with that directory mounted at /workspace."
