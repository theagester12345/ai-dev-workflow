# CLAUDE.md - {{PROJECT_NAME}} Frontend

Project context for AI coding assistants.

## Scope

**Your workspace is `{{SIDE_DIR}}/`.** Edit only files here (+ root config if explicitly asked).

In a monorepo:
- **Read-only:** `{{OTHER_SIDE}}/` (don't edit backend)
- If asked about backend: say it's out of scope, point to `{{OTHER_SIDE}}/`

## Communication Convention

**Canonical:** [`../WORKFLOW.md` → Communication](../WORKFLOW.md#communication-short-by-default). Short by default; `DA` = force detail (short is the default).

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

**Agents read `.env.example` (names), never `.env` values** — see [WORKFLOW.md → Secrets & environment](../WORKFLOW.md#secrets--environment). Never commit `.env`/`.env.local`.

## Operating Modes

**Canonical:** [`../WORKFLOW.md` → Operating Modes](../WORKFLOW.md#operating-modes-spec--build).

## Task Synchronization Protocol

**Canonical:** [`../WORKFLOW.md` → Task Synchronization Protocol](../WORKFLOW.md#task-synchronization-protocol).

## SESSION_LOG Protocol

**Canonical:** [`../WORKFLOW.md` → SESSION_LOG Protocol](../WORKFLOW.md#session_log-protocol).

## Documentation Update Protocol

**Canonical:** [`../WORKFLOW.md` → Documentation Update Protocol](../WORKFLOW.md#documentation-update-protocol).

---

_{{PROJECT_NAME}} Frontend — {{LANGUAGE}} / {{FRAMEWORK}}_

---

## Documents

<!-- Curated entries belong ABOVE the markers — a key doc plus one line on what it is for.
     That half is agent-owned and survives regeneration. -->

### File index (auto — maintained by `adapters/index/emit-index.sh`; do NOT edit inside the markers)

<!-- INDEX:START -->
<!-- INDEX:END -->

---

## Design Workflow

**Canonical spine:** [`../WORKFLOW.md` → UI mock design self-review](../WORKFLOW.md#ui-mock-design-self-review--before-human-approval). This section is the **Binding** — paths and checklist. It may **narrow** the spine, never skip the agent design pass, the browser-open, human approval before source, or visual source-of-truth through implementation.

### The single mock (the reviewable artifact)
1. Write a short **screen intent** note — the job, key elements, primary action, states. Keep it wherever this project keeps UX notes.
2. Build **one** HTML mock under `mockups/<task-or-screen>/` (see [`mockups/README.md`](./mockups/README.md)), using the project's real styling so it renders ≈1:1 with the eventual component. **Do not put mocks in `/tmp/`** — sandboxed browsers cannot read the host's `/tmp`.
3. **Agent design self-review** against [`mockups/DESIGN_REVIEW.md`](./mockups/DESIGN_REVIEW.md). Fix material findings *before* showing the human.
4. **Open the mock in a real browser** for the human, on every edit round. A path or a description is not a review. If the screen has several rendering modes, the mock presents all of them; modes it deliberately does not support are recorded as exempt on the checklist.
5. Human approval is stamped on the screen's record — **only then** may application source for that screen be edited.
6. **Implement from the approved mock as the visual source of truth.** Preserve its section surfaces, palette relationships and spacing hierarchy; do not wash them through theme tokens until they match. Before marking the task done, open the shipped screen and confirm it reads like the mock, in every supported mode.
7. If the screen introduced **new design language**, capture the tokens or patterns in the same change — in this project's design-system doc if it has one.

### Rules
- Naming the BUILD task authorizes this whole loop for **that screen only**.
- Mock HTML/CSS is project-local working material, not payload — keep it out of version control if it is throwaway.
