# STACK — resolved project stack

> ⚠️ STARTER — fill this in during [BOOTSTRAP](./BOOTSTRAP.md), then remove this banner.
> This is the **single source of truth** for the concrete stack. The docs reference it; when a value changes, change it here.

| Attribute | Value |
|---|---|
| Project name | `{{PROJECT_NAME}}` |
| Shape | `two sides (backend + frontend)` \| `one side` — how many **independently buildable** sides |
| **Backend** | |
| Language | `{{LANGUAGE}}` |
| Framework | `{{FRAMEWORK}}` |
| Build tool | `{{BUILD_TOOL}}` |
| Database / persistence | `{{DB}}` |
| Auth | `{{AUTH}}` |
| Test framework | `{{TEST_FRAMEWORK}}` |
| API base path | `{{API_BASE_PATH}}` |
| **Frontend** | |
| Language | `{{LANGUAGE}}` |
| Framework | `{{FRAMEWORK}}` |
| Build tool | `{{BUILD_TOOL}}` |
| Test framework | `{{TEST_FRAMEWORK}}` |
| Styling | `e.g. Tailwind CSS` |
| **Shared** | |
| Task tracker | `optional — TASK.md is source of truth; any board is a one-way mirror Binding` |
| Persona — backend | `{{ARCHITECT_NAME}}` |
| Persona — frontend | `{{ARCHITECT_NAME}}` |

## Code paths (per side)

A workspace directory is a persona's **doc home**; code lives where the stack puts it. Record each side's writable code paths here.

| Side | Doc home | Code paths (writable) |
|---|---|---|
| Backend | `backend/` | `e.g. backend/src/, backend/pom.xml` |
| Frontend | `frontend/` | `e.g. frontend/src/, frontend/package.json` |

> **Never move source code to fit the doc layout** — the stack decides code location.

## Commands

| Action | Backend | Frontend |
|---|---|---|
| Run dev | `{{RUN_CMD}}` | `{{RUN_CMD}}` |
| Build | `{{BUILD_CMD}}` | `{{BUILD_CMD}}` |
| Test | `{{TEST_CMD}}` | `{{TEST_CMD}}` |
| Lint / typecheck | `{{LINT_CMD}}` | `{{LINT_CMD}}` |

## Notes

_Anything stack-specific that future sessions need (env var names, ports, external services, deploy targets) goes here._
