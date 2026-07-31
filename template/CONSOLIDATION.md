# CONSOLIDATION — keep the append-only docs lean

> ⚠️ STARTER — unbootstrapped. After [`BOOTSTRAP.md`](./BOOTSTRAP.md), remove this banner. (This protocol file **stays** in the project — it is not deleted at bootstrap.)

Append-only docs grow forever and are re-read every session — bloat costs tokens on every read and buries the signal. Periodically **distill** them. This is the *ongoing* token-hygiene layer (the complement to the one-time `scaffold.sh` fill).

## Which docs, and where stale content goes

| Doc | What to consolidate | Archive to |
|---|---|---|
| `*/SESSION_LOG.md` | merge/dedupe related lessons; drop superseded ones | `SESSION_LOG_ARCHIVE.md` (same dir) |
| `*/TASK.md` (COMPLETED) | move old completed tasks out | `TASK_ARCHIVE.md` (or rely on git + your tracker) |
| `*/INTERFACE.md` | move ACKed/closed entries out | `INTERFACE_ARCHIVE.md` |

## When to run it

- **At session start**, the workspace agent notes any append-only doc over a soft threshold and **offers** to consolidate — rough triggers: `SESSION_LOG` > ~30 entries, `TASK.md` COMPLETED > ~40, `INTERFACE.md` ACKed > ~20.
- **On demand:** tell the agent **"consolidate <doc>"**.

## How (rules)

- **Archive, never delete.** Move stale entries to the sibling `*_ARCHIVE.md`; keep the *live* doc lean (that's the one read every session). Git already holds history; the archive keeps it human-readable.
- **Preserve ids** and never silently drop a lesson/decision — merge or move, don't erase.
- **Propose-then-approve.** These are judgment/history docs — show the before/after and get the user's OK before rewriting.
- Keep the live doc's newest, still-relevant entries; archive is reverse-chronological too.

_The `*_ARCHIVE.md` files are committed (they're history) — don't gitignore them._
