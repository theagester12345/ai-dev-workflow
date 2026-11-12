# ADOPT — Retrofit into Existing Project

Use this guide when adding the workflow to a project that already has code and docs.

**Prime directive:** Existing docs are authoritative. NEVER overwrite real content with template stubs.

## Key Differences from Bootstrap

- No placeholders to fill (the project is already concrete)
- Focus on **adding missing structure**, not creating from scratch
- **Merge** new conventions into existing docs, don't replace
- **Classify and migrate** misfiled content (with approval)

## Procedure

0. **The first card is a credential sweep**
   - The workflow's secret rules stop new leaks; nothing has looked at what the project already holds — a password in a migration comment, a token in an old commit, a value in a shell history.
   - File it on the side that owns the deploy, and run [`adapters/secret-sweep/`](./adapters/secret-sweep/README.md): the working tree, the whole history, and the shell, database-client and agent-log paths **the user names** (never a guess). Output is masked; nobody pastes a value anywhere.
   - **Each high-risk find becomes its own card**, naming the owner's steps (rotate it, scrub their machine), with criteria checkable without the value.
   - Re-run the sweep whenever a leak is suspected. A fresh bootstrap has no history to sweep and skips this.

1. **Inventory existing structure**
   - What workspaces exist? (backend, frontend, both?)
   - What documentation exists? Where is it?
   - What's the current task tracking method?

2. **Gap analysis**
   - Missing workspace docs? (CLAUDE.md, ARCHITECT.md, TASK.md, SESSION_LOG.md)
   - Missing conventions? (operating modes, task format, session log protocol)
   - Inconsistencies between workspaces?

3. **Add missing files**
   - Copy templates for missing workspace docs
   - Fill with concrete project info (no placeholders)
   - Don't overwrite existing files
   - **An `AGENTS.md` the repo already has is its own** (no `EMITTED Binding` marker): the emit and the pre-commit hook never overwrite or stage it. A host that reads only `AGENTS.md` then does not reach the workflow from it — [`adapters/agents/README.md`](./adapters/agents/README.md).

4. **Retrofit conventions surgically**
   - If existing CLAUDE.md lacks operating modes → add that section
   - If task format differs → propose migration to canonical format
   - If no session log → add one with the protocol
   - Edit only affected sections; preserve all existing content

5. **Migrate misfiled content (with approval)**
   - Backend docs in wrong place? Propose `git mv`
   - Task tracking scattered? Consolidate to `TASK.md`
   - **Always get approval before moving files**

6. **Verify consistency**
   - Both workspaces reference `WORKFLOW.md`
   - Task format is consistent
   - Operating modes are defined
   - Links resolve correctly

## What NOT to Do

- ❌ Overwrite populated docs with template stubs
- ❌ Move files without approval
- ❌ Force canonical format over working alternatives
- ❌ Add placeholders to concrete docs
- ❌ Delete working conventions that differ slightly

## Adoption Checklist

- [ ] Credential sweep run; each high-risk find has its own card
- [ ] All workspaces have CLAUDE.md with operating modes
- [ ] TASK.md exists with canonical format
- [ ] SESSION_LOG.md exists with protocol
- [ ] ARCHITECT.md exists for SPEC mode guidance
- [ ] WORKFLOW.md added and referenced
- [ ] No existing content was overwritten
- [ ] All file moves were approved
- [ ] Links work, no broken references

---

_Adopt incrementally. Preserve what works. Add structure where it's missing._
