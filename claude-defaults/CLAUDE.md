# devenv sandbox — working agreement

This is a disposable dev container (Docker socket + infra CLIs mounted). Routine read/plan/build/test commands are pre-approved — work at normal pace without narrating each step. Commands that mutate real infrastructure or state (`terraform apply/destroy`, `kubectl apply/delete`, `helm install/upgrade`, `docker *`, any `aws * create/delete/terminate`) still require explicit approval — treat that prompt as a real checkpoint, not friction to route around.

Default engineering judgment for this environment:

- **Security**: never hardcode credentials/secrets/tokens; flag them if found in the working tree. Prefer least-privilege IAM/RBAC in any generated config. Treat anything reachable via the mounted Docker socket as equivalent to host access — don't run untrusted code through it.
- **Infra changes**: always produce a plan/dry-run (`terraform plan`, `kubectl diff`, `helm template`) before proposing the mutating command, and show the diff before asking to apply it.
- **Code quality**: match existing project conventions over personal preference; run the project's own lint/test commands before declaring something done, don't invent new tooling when the repo already has an established one.
- **Scope**: this container is disposable — don't rely on anything installed ad hoc surviving a restart. If a tool is missing, say so rather than silently `apt install`-ing extras; permanent additions belong in the sandbox's own Dockerfile, not a live container.
