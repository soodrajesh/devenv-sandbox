# devenv-sandbox

A disposable, pre-provisioned dev container for testing infra tooling (Kubernetes manifests, Terraform, AWS CLI, Docker) without touching your host machine. One command brings it up with everything pre-installed, your current directory mounted, and Claude Code already authenticated.

## What's installed

| Tool | Version | Notes |
|---|---|---|
| Debian | bookworm-slim | base image |
| Python | 3.11 | + pip, venv |
| Node.js | 22.x | via NodeSource (Debian's apt package is too old for Claude Code) |
| AWS CLI | v2 (latest) | official installer |
| kubectl | 1.31.0 | pinned |
| Helm | 3.16.2 | pinned |
| Terraform | 1.9.8 | pinned |
| Docker CLI | latest | **client only** — no daemon, see below |
| Claude Code | latest | npm global install |
| git, curl, jq, vim, unzip | latest (apt) | |

Version pins live at the top of the [Dockerfile](Dockerfile) as build args — bump them there when you want an upgrade.

## Requirements

- Docker Desktop (or another Docker daemon) installed and running
- macOS/Linux with bash

## Install

```bash
git clone https://github.com/soodrajesh/devenv-sandbox.git
cd devenv-sandbox
./install.sh
```

This symlinks `devenv` to `/usr/local/bin/devenv` and does the first image build. If you'd rather not touch `/usr/local/bin`, skip `install.sh` and just run `./devenv` directly from this directory (or add this directory to your `PATH`).

## Usage

From any project directory:

```bash
devenv up
```

This mounts your **current working directory** into the container at `/workspace`, drops you into a bash shell, and:

- rebuilds the image automatically if the Dockerfile has changed since the last build (otherwise reuses the cached image — near-instant start)
- mounts your host's Docker socket in, so `docker`, and anything that talks to Docker (`kind`, `docker compose`, etc.) works against your **host's** Docker, not a nested daemon
- mounts `~/.claude` in, so `claude` inside the container is already logged in with your host session/config

Subcommands:

```bash
devenv up      # build if stale, then start (default)
devenv build   # force a rebuild without starting a shell
devenv shell   # alias for up
```

Exit the shell (`exit` or Ctrl-D) and the container is gone — nothing persists except what you did inside `/workspace` (because that's a bind mount to your real files) or pushed/pulled through the mounted Docker socket.

## Design decisions (read before you rely on this)

**This is not a security sandbox.** The container mounts `/var/run/docker.sock`, which gives anything running inside it root-equivalent control over your host's Docker — it can start, stop, or inspect any container on your machine, mount arbitrary host paths into new containers, etc. Containers you start "inside" this sandbox (e.g. via `kind` or `docker run`) are actually siblings running on your host, not nested inside it. Treat this as a **convenience environment for tooling you trust**, not isolation for untrusted code.

**Disposable by design.** Every `devenv up` starts a fresh container (`--rm`). Anything you `apt install` or `pip install` ad hoc inside the shell is gone when you exit. If you need something persistently, add it to the [Dockerfile](Dockerfile) and rebuild — that's the intended workflow, so the container never drifts from what's documented here.

**Be careful what directory you run this from.** `devenv up` mounts whatever directory you're in as `/workspace`, read-write, into a container that also has host Docker access. Don't run it from a directory containing files you wouldn't want exposed to that combination (e.g. a directory with unencrypted credentials/`.env` files) unless that's intentional.

## Uninstall

```bash
rm /usr/local/bin/devenv
docker rmi devenv-sandbox:latest
rm -rf /path/to/devenv-sandbox   # this cloned repo
```
