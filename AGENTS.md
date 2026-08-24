# Agent Instructions

This project uses the workflow in `.ai/workflow/`.

Before changing project artifacts:

1. Read `.ai/workflow/rules/workflow.md` and `.ai/workflow/rules/governance.md`.
2. Read `.ai/project-rules.md`, `.ai/state/current.md`, `docs/project-overview.md`, and `docs/pre-code.md`.
3. Identify the active role from `.ai/workflow/agents/`.
4. Do not create, modify, rename, or delete any repository file unless acting as Worker with a valid task packet and write lease.
5. Stop on baseline drift, path outside allowlist, contract conflict, or missing owner decision.
6. A Worker must not audit its own candidate; an Auditor must remain read-only.

Project-specific instructions may tighten these rules but may not silently weaken authority, lease, independence, or evidence requirements.
