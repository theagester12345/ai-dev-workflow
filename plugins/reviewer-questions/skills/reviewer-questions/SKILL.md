---
name: reviewer-questions
description: 'Use after finishing a change and before its review or commit: stop and ask the user whether they left questions in the code, then collect every one in the files this change touched as one set, or run a silent guard scan when they say proceed. Also when the user says "collect" or "proceed" about their questions.'
license: MIT
---

# Reviewer questions — collect them, don't stumble on them

A person reviewing an agent's work as it streams past leaves questions where they arise, as comments in the code. A question inside a hunk the agent is already looking at gets noticed in passing. The same question twenty lines away, in code the change did not touch, is never seen. Finding *some* of them is what incidental discovery does. This procedure **collects** them instead.

## The marker

A question is a comment carrying the marker token followed by a colon. The default token is `AI-Questions`. The scan is case-insensitive and the trailing `s` is optional, because the marker is typed mid-read and the singular is the natural slip. The comment syntax around it (`//`, `#`, `<!-- -->`) is not part of the token, so one scan covers every file type. A project that uses another token passes it with `--marker <token>`.

## The procedure

1. **When the change is finished, stop and ask:** *"Any questions in the code? Say **collect** or **proceed**."* Do not scan first and do not report a count. Only the user knows whether they are done reading. A scan at this moment reads a review still being written, so zero means "nothing yet", not "nothing".
2. **Declare the file set:** the files this session changed, from its own edits. Write the list down before scanning. Never derive it from `git status`: in a shared checkout that hands you another session's questions.
3. **On *collect*:** run one scan over the declared set and present **every** in-scope marker as a single set.
   ```sh
   sh <this skill's folder>/scripts/scan-questions.sh [--marker <token>] <declared files…>
   ```
   Exit `1` means questions were found. Discuss them. If the discussion raises more, the user may add more markers; scan again until they say proceed.
4. **On *proceed*:** run the same command as a **guard scan**. It answers nothing. Exit `0` passes; exit `1` means markers remain, so refuse to go on and show them.
5. **Answer each question where it belongs:**
   - a code change goes in the code;
   - a decision goes wherever the project records decisions;
   - a pure explanation becomes a comment at the site of the question, saying **why** the code is that way. The question proves a capable reader could not tell.
6. **Delete the markers last, as their own announced step**, after the discussion is closed. Never collect and delete in one move, which destroys the question before it is answered. An edit that rewrites the region a marker sits in deletes it by accident, and the next scan then reports a clean set: surface that question before the edit lands.
7. **Run the guard scan again just before the commit.** The user may still be reading.

## Out of scope

The scanner reads the whole repository but collects only inside the declared set. Markers elsewhere are **reported by path and never edited**. Each one needs a decision from the user, not just a mention: make it separate work, leave it to whoever owns that file, or widen this change's declared set to include it. Answering it on a spoken "go ahead" without widening the set first edits a file no review covers.

## The script

`scripts/scan-questions.sh` is POSIX `sh` and git, with no other dependencies. Exit `0`: no markers in the declared set. Exit `1`: markers to answer. Exit `2`: a usage error, such as no paths or a blank argument, which is refused rather than read as the whole repository. Files that only *define* the marker, such as an `AGENTS.md` or a `STACK.md`, are skipped by default; add your own with `--exempt <path>`. Tests: `sh scripts/scan-questions.test.sh`.

---

Part of [AI Dev Workflow](https://github.com/theagester12345/ai-dev-workflow), which runs a software project with a team of AI agents.
