# CLAUDE.md - {{PROJECT_NAME}} Frontend

Project context for AI coding assistants.

## Scope

**Your workspace is `{{SIDE_DIR}}/`.** Edit only files here (+ root config if explicitly asked).

In a monorepo:
- **Read-only:** `{{OTHER_SIDE}}/` (don't edit backend)
- If asked about backend: say it's out of scope, point to `{{OTHER_SIDE}}/`

## Communication Convention

**Canonical:** [`../WORKFLOW.md` → Communication](../WORKFLOW.md#communication-default-concise). Default concise; `SA`/`DA` override.

## Task Tracker

**Before and after ANY implementation work, consult [`TASK.md`](./TASK.md)** — the canonical task tracker. See [Task Synchronization Protocol](#task-synchronization-protocol).

## Quick Reference

```bash
{{RUN_CMD}}      # Start dev server
{{BUILD_CMD}}    # Production build
{{TEST_CMD}}     # Run tests
```

## Project Overview

**Stack:** {{LANGUAGE}} / {{FRAMEWORK}}

**Purpose:** _<one-line product purpose>_

**Architecture:** _<single app / monorepo structure>_

**Backend:** separate API (`{{API_BASE_PATH}}`)

## Tech Stack

- **Framework:** {{FRAMEWORK}}
- **Language:** {{LANGUAGE}}
- **Styling:** _<CSS framework>_
- **Backend integration:** direct API calls to `{{API_BASE_PATH}}`
- **Tooling:** {{BUILD_TOOL}}

## Critical Rules

> Translate these principles to {{LANGUAGE}}/{{FRAMEWORK}} per [BOOTSTRAP.md Principle→Binding table](../BOOTSTRAP.md#principle--binding-translation).

1. **Server vs Client boundary:** Default to server-side; push interactivity to lowest client boundary. _<bind to {{FRAMEWORK}}: e.g. `"use client"` only where needed>_

2. **Backend API via chokepoint:** Call backend through single helper that applies `{{API_BASE_PATH}}` and attaches auth. Don't hardcode version at call sites.

3. **Strict typing:** No `any` (use `unknown`); explicit return types on exports; types for data shapes.

4. **Validation at edge:** All forms use schema validator; import canonical field schemas from shared module.

5. **Immutability:** Prefer non-reassignment; copy-then-change over mutate. _<bind: `const` over `let`, spread over push>_

6. **Metadata & SEO:** Every page exports metadata (title/description).

## Coding Conventions

### Components

- Typed props; named exports
- Keep small and composable
- Co-locate only what's used together

### State Management

| State type | Where it lives |
|------------|----------------|
| Global (auth/session) | Minimal global store |
| Form state | Schema-backed form library |
| URL state (filters/sort) | The URL (shareable) |
| Server state (API data) | Server fetch / data layer |
| Local UI state | Component-local |

### File Naming

- Components: PascalCase
- Utilities: camelCase
- Routes/pages: per {{FRAMEWORK}} convention

## Calling the Backend API

Version lives in one chokepoint — an `API_BASE` constant. Prefer `apiFetch` helper with version-less path:

```typescript
// Preferred — authed, versioned via chokepoint:
const res = await apiFetch("/users/me");
// → <host>{{API_BASE_PATH}}/users/me + auth
```

## Environment Variables

```bash
# App
NEXT_PUBLIC_API_URL=<backend host>  # host only; version in API_BASE constant
```

## Operating Modes

**Canonical:** [`../WORKFLOW.md` → Operating Modes](../WORKFLOW.md#operating-modes-plan--build).

## Task Synchronization Protocol

**Canonical:** [`../WORKFLOW.md` → Task Synchronization Protocol](../WORKFLOW.md#task-synchronization-protocol).

## SESSION_LOG Protocol

**Canonical:** [`../WORKFLOW.md` → SESSION_LOG Protocol](../WORKFLOW.md#session_log-protocol).

## Documentation Update Protocol

**Canonical:** [`../WORKFLOW.md` → Documentation Update Protocol](../WORKFLOW.md#documentation-update-protocol).

---

_{{PROJECT_NAME}} Frontend — {{LANGUAGE}} / {{FRAMEWORK}}_
