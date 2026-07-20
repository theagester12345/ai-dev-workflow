# BOOTSTRAP — First-time Setup Guide

This project was scaffolded with a stack-agnostic workflow template. Your job is to resolve placeholders (`{{LIKE_THIS}}`) and translate principles to your concrete stack.

## Procedure

1. **Determine the stack** — If existing code, detect from build files. If greenfield, ask the user for: language, framework, build tool, test framework, database, auth.

2. **Replace all `{{PLACEHOLDERS}}`** with concrete values (see registry below). Verify with: `grep -rn "{{" .`

3. **Translate principles to stack-specific rules** using the Principle → Binding table below. Keep the intent; change the mechanism.

4. **Remove this file** when done.

## Placeholder Registry

| Placeholder | Example |
|-------------|---------|
| `{{PROJECT_NAME}}` | MyApp |
| `{{SIDE}}` | Backend / Frontend |
| `{{SIDE_DIR}}` | backend / frontend |
| `{{OTHER_SIDE}}` | frontend / backend |
| `{{LANGUAGE}}` | Java 21 / TypeScript 5 |
| `{{FRAMEWORK}}` | Spring Boot 3.2 / Next.js 15 |
| `{{BUILD_TOOL}}` | Maven / npm |
| `{{RUN_CMD}}` | `mvn spring-boot:run` / `npm run dev` |
| `{{BUILD_CMD}}` | `mvn package` / `npm run build` |
| `{{TEST_CMD}}` | `mvn test` / `npm test` |
| `{{API_BASE_PATH}}` | /api/v1 |

## Principle → Binding Translation

### 1. Immutability
Prefer non-reassignment; make mutation the exception.

| Stack | Binding |
|-------|---------|
| Java | `final` on params/locals/fields; `record` for DTOs |
| TypeScript | `const` over `let`; `readonly` props; spread to copy |
| Python | `Final` annotations; frozen dataclasses |
| Go | Value semantics; avoid in-place mutation |
| Kotlin | `val` over `var`; immutable collections |

### 2. Dependency Injection
Inject collaborators; don't construct them inline.

| Stack | Binding |
|-------|---------|
| Java/Spring | Constructor injection with `final` fields |
| TypeScript | Constructor params; avoid module-level singletons |
| Python | Pass deps to `__init__`; use DI container if needed |
| Go | Accept interfaces as struct fields |

### 3. Separate Request/Response Types
Never a single generic DTO.

| Stack | Binding |
|-------|---------|
| Any | Input: validation + writable fields only. Output: all fields + metadata, no validation. Name: `{Entity}RequestDTO` / `{Entity}ResponseDTO` |

### 4. Layered Separation
HTTP layer is thin; logic lives in services; data access is isolated.

| Stack | Binding |
|-------|---------|
| Java/Spring | Controller (routing) → Service (logic) → Repository (data) |
| Next.js | Server Component/route → lib/service → API client |
| Express | Route → service → repository/model |

### 5. Validation at the Edge
All external input is schema-validated.

| Stack | Binding |
|-------|---------|
| Java | Bean Validation (`@NotNull`, `@Email`) on request DTOs |
| TypeScript | Zod schemas; infer types from schemas |
| Python | Pydantic models |

### 6. Strict Typing
No escape hatches.

| Stack | Binding |
|-------|---------|
| TypeScript | `strict: true`; no `any` (use `unknown`) |
| Python | Type hints; mypy/pyright strict mode |
| Java/Go | Already strict; avoid raw types |

### 7. Operating Modes
Every session declares one mode.

| Mode | Purpose | Actions |
|------|---------|---------|
| SPEC | Design, architecture, task breakdown | Writes to `TASK.md`; reads everything; no code changes |
| BUILD | Implementation | Code changes; moves tasks from TODO → COMPLETED |

## Cleanup Checklist

- [ ] All `{{PLACEHOLDERS}}` replaced
- [ ] Principles translated to stack-specific rules
- [ ] `grep -rn "{{" .` returns nothing
- [ ] This BOOTSTRAP.md deleted
