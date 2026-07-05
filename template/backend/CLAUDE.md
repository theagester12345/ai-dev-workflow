# CLAUDE.md - {{PROJECT_NAME}} Backend

Project context for AI coding assistants.

## Scope

**Your workspace is `{{SIDE_DIR}}/`.** Edit only files here (+ root config if explicitly asked).

In a monorepo:
- **Read-only:** `{{OTHER_SIDE}}/` (don't edit the other side)
- If asked about frontend: say it's out of scope, point to `{{OTHER_SIDE}}/`

## Communication Convention

**Canonical:** [`../WORKFLOW.md` → Communication](../WORKFLOW.md#communication-default-concise). Default concise; `SA`/`DA` override.

## Task Tracker

**Before and after ANY implementation work, consult [`TASK.md`](./TASK.md)** — the canonical task tracker. See [Task Synchronization Protocol](#task-synchronization-protocol).

## Quick Reference

```bash
{{RUN_CMD}}      # Start dev server
{{TEST_CMD}}     # Run tests
{{BUILD_CMD}}    # Production build
```

**API Base Path:** `{{API_BASE_PATH}}`

## Project Overview

**Stack:** {{LANGUAGE}} / {{FRAMEWORK}}

**Purpose:** _<one-line product purpose>_

**Authentication:** _<auth mechanism>_

**Database:** _<database>_

## Tech Stack

- **Framework:** {{FRAMEWORK}}
- **Language:** {{LANGUAGE}}
- **Build:** {{BUILD_TOOL}}
- **Testing:** _<test framework>_

## Critical Rules

> Translate these principles to {{LANGUAGE}}/{{FRAMEWORK}} per [BOOTSTRAP.md Principle→Binding table](../BOOTSTRAP.md#principle--binding-translation).

1. **Dependency injection:** Inject collaborators via constructor; no inline construction of dependencies.

2. **Separate Request/Response types:** Never one generic `{Entity}DTO`. Request = writable fields + validation; Response = all fields + metadata, no validation.

3. **Controllers are thin:** HTTP routing, param extraction, delegate to service, return response. All business logic lives in services.

4. **Transactional writes:** Service methods that write data are transactional.

5. **Validate at the edge:** Request types carry schema validation; bad input yields clean 400, never 500.

6. **Immutability:** Non-reassigned values are immutable; mutation is the exception. _<bind to {{LANGUAGE}}: `final` / `const` / `val` / `Final`>_

## Architecture & Coding Conventions

### Layer Responsibilities

| Layer | Purpose |
|-------|---------|
| **Controller** | HTTP routing only. Delegates to service. |
| **Service** | Business logic, transactions, orchestration. |
| **Repository** | Data access only. |
| **DTO** | Request/Response transfer objects. |

### Code Style

- **Immutability:** prefer immutable by default
- **Injection:** constructor injection
- **Configuration:** read from typed config, not magic literals
- **Timestamps:** framework-managed where possible

### Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Domain model | Singular | `Property`, `User` |
| Table | Plural snake_case | `properties`, `users` |
| Request DTO | `{Entity}RequestDTO` | `PropertyRequestDTO` |
| Response DTO | `{Entity}ResponseDTO` | `PropertyResponseDTO` |
| Service/Controller/Repository | `{Entity}{Role}` | `PropertyService` |

## API Surface

> Document endpoints as they ship.

| Resource | Base Path | Operations | Auth |
|----------|-----------|------------|------|
| _<Resource>_ | `{{API_BASE_PATH}}/...` | _<ops>_ | _<public/authed>_ |

### Integration Contract

- **Auth:** _<who does authn vs authz>_
- **CORS:** env-driven origins
- **Error shape:** consistent JSON (`{ timestamp, status, error, message }`)
- **Pagination:** stable wrapper, never bare array

## Environments & Config

- **Profiles:** local (dev), dev (staging), prod
- **Migrations:** managed by migration tool; ORM in validate mode
- **Secrets:** from env vars; never commit; `.env.example` in repo

## Testing

Run: `{{TEST_CMD}}`

**Layers:**
- Service unit tests (mock repositories)
- Integration tests (full stack)
- Data layer tests

## Operating Modes

**Canonical:** [`../WORKFLOW.md` → Operating Modes](../WORKFLOW.md#operating-modes-plan--build).

## Task Synchronization Protocol

**Canonical:** [`../WORKFLOW.md` → Task Synchronization Protocol](../WORKFLOW.md#task-synchronization-protocol).

## SESSION_LOG Protocol

**Canonical:** [`../WORKFLOW.md` → SESSION_LOG Protocol](../WORKFLOW.md#session_log-protocol).

## Documentation Update Protocol

**Canonical:** [`../WORKFLOW.md` → Documentation Update Protocol](../WORKFLOW.md#documentation-update-protocol).

---

_{{PROJECT_NAME}} Backend — {{LANGUAGE}} / {{FRAMEWORK}}_
