# devenv-sandbox

A disposable, pre-provisioned dev container for testing infra tooling (Kubernetes manifests, Terraform, AWS CLI, Docker) without touching your host machine. One command brings it up with everything pre-installed, your current directory mounted, and Claude Code already authenticated.

## What's installed

| Tool | Version | Notes |
|---|---|---|
| Debian | bookworm-slim | base image, pinned to a digest (see Dockerfile) |
| Python | 3.11 | + pip, venv |
| Node.js | 22.x | via NodeSource (Debian's apt package is too old for Claude Code) |
| AWS CLI | v2 (latest) | official installer |
| kubectl | 1.31.0 | pinned |
| Helm | 3.16.2 | pinned |
| Terraform | 1.9.8 | pinned |
| Docker CLI | latest | **client only** — no daemon, see below |
| Claude Code | latest | npm global install |
| git, curl, jq, vim, unzip | latest (apt) | |

Version pins live at the top of the [Dockerfile](Dockerfile) as build args. The base image is pinned by digest, and kubectl/Helm/Terraform downloads are checksum-verified at build time — when bumping a version, update both the version arg and its matching `*_SHA256` arg (the Dockerfile comments show where to pull each checksum from).

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
- mounts just `~/.claude/.credentials.json`, `settings.json`, and `CLAUDE.md` in (not the whole `~/.claude` directory — see below), so `claude` inside the container is already logged in
- if the project you mounted has no `.claude/` or `CLAUDE.md` of its own, injects sandbox defaults (see below) so `claude` inside the container doesn't nag for every routine command but still stops for anything that mutates real infra

### Claude Code defaults inside the sandbox

[`claude-defaults/.claude/settings.json`](claude-defaults/.claude/settings.json) and [`claude-defaults/CLAUDE.md`](claude-defaults/CLAUDE.md) are mounted into `/workspace` on every `devenv up`, **unless the mounted project already has its own** (existing project config always wins — these are only a fallback for bare projects).

What they do:

- **Auto-approved**: file edits, `git`, read-only `kubectl`/`helm`/`terraform`/`aws` commands (`get`, `describe`, `plan`, `template`, `lint`, `diff`, `--dry-run`, etc.), package managers, test runners
- **Still requires approval**: anything that mutates real state — `terraform apply/destroy`, `kubectl apply/delete`, `helm install/upgrade/uninstall`, `docker *`, `aws * create/delete/terminate`, `sudo`, `rm -rf`, and piping a remote script straight into `bash`/`sh`
- **CLAUDE.md** tells Claude to default to security/best-practice judgment (no hardcoded secrets, least-privilege configs, dry-run before mutating commands, match existing project conventions) rather than staying silent on it

This is a curated allowlist, not full bypass mode (`--dangerously-skip-permissions`) — the container already has host Docker socket access via the mount above, so anything that reaches through that socket stays gated behind a real approval prompt. Edit [`claude-defaults/.claude/settings.json`](claude-defaults/.claude/settings.json) directly if you want to loosen or tighten the list.

Subcommands:

```bash
devenv up      # build if stale, then start (default)
devenv build   # force a rebuild without starting a shell
devenv shell   # alias for up
devenv clean   # prune dangling image layers left behind by rebuilds
```

Environment variables:

```bash
DEVENV_WORKSPACE=/path/to/project devenv up   # mount a specific dir instead of the current one
```

Exit the shell (`exit` or Ctrl-D) and the container is gone — nothing persists except what you did inside `/workspace` (because that's a bind mount to your real files) or pushed/pulled through the mounted Docker socket.

If a directory you mount contains a top-level `.env`, `.env.*`, or `*.env` file, `devenv up` prints a warning before starting — those files get exposed read-write to a container that also has host Docker access. It's a warning, not a block; move or exclude the file yourself if you don't want it in there.

## Design decisions (read before you rely on this)

**This is not a security sandbox.** The container mounts `/var/run/docker.sock`, which gives anything running inside it root-equivalent control over your host's Docker — it can start, stop, or inspect any container on your machine, mount arbitrary host paths into new containers, etc. Containers you start "inside" this sandbox (e.g. via `kind` or `docker run`) are actually siblings running on your host, not nested inside it. Treat this as a **convenience environment for tooling you trust**, not isolation for untrusted code.

**Disposable by design.** Every `devenv up` starts a fresh container (`--rm`). Anything you `apt install` or `pip install` ad hoc inside the shell is gone when you exit. If you need something persistently, add it to the [Dockerfile](Dockerfile) and rebuild — that's the intended workflow, so the container never drifts from what's documented here.

**Be careful what directory you run this from.** `devenv up` mounts whatever directory you're in as `/workspace`, read-write, into a container that also has host Docker access. Don't run it from a directory containing files you wouldn't want exposed to that combination (e.g. a directory with unencrypted credentials/`.env` files) unless that's intentional.

**Only three files from `~/.claude` are mounted in, not the whole directory.** `~/.claude` on the host also holds `mcp.json` (local MCP server config — commonly contains plaintext API tokens for connectors like GitHub/Vercel), full conversation history under `projects/`, and session state. None of that is needed to authenticate `claude` inside the container, so `devenv` only mounts `.credentials.json`, `settings.json`, and `CLAUDE.md` individually rather than the whole directory. This blocks any **file-based** MCP server (anything defined in `mcp.json`, which carries its own separate raw token per server).

**What this does *not* block: `claude.ai` account-level connectors** (e.g. Gmail, Google Drive, Vercel when connected through claude.ai rather than a local `mcp.json` entry). Those ride on the OAuth session inside `.credentials.json` itself — there's no CLI flag or config file that suppresses them independently of that session (tested: `--strict-mcp-config` with an empty MCP config has no effect on them). The only way to fully exclude them would be to stop mounting `.credentials.json` and re-authenticate `claude` manually every session — traded off here in favor of not having to log in every time, since this is a single-user local tool. If that tradeoff ever stops being acceptable, dropping the `.credentials.json` mount in [`devenv`](devenv) is the fix.

**Auto-injected `.claude/` defaults clean up after themselves.** If the project you mount has no `.claude/` or `CLAUDE.md` of its own, `devenv` mounts the sandbox defaults in for the session and then removes the (empty) stub directory/file it created once the container exits — so bare projects don't accumulate leftover `.claude/` folders over repeated runs. If you actually write something into `.claude/` or `CLAUDE.md` during the session, cleanup skips it and leaves your changes in place.

## Uninstall

```bash
rm /usr/local/bin/devenv
docker rmi devenv-sandbox:latest
rm -rf /path/to/devenv-sandbox   # this cloned repo
```
