# Mock design self-review

> ⚠️ STARTER — unbootstrapped. After [`../../BOOTSTRAP.md`](../../BOOTSTRAP.md), remove this banner. This file **stays** (Binding checklist for the spine gate).

**Who runs it:** the agent, every time a reviewable mock is created or edited.  
**When:** after the mock HTML exists, **before** opening the browser for human review.  
**Canonical:** [`../../WORKFLOW.md` → UI mock design self-review](../../WORKFLOW.md#ui-mock-design-self-review--before-human-approval).

Human approval on the section record is still required. This gate does not replace it.

## Checklist — default surface

Mark each; fix **material** fails before browser handoff.

| # | Check | Pass? |
|---|---|---|
| 1 | Adjacent sections don’t share the same dominant surface | |
| 2 | One job per section (headline + short support + one primary action max) | |
| 3 | Clear CTA hierarchy (one primary, secondary is quieter) | |
| 4 | Text contrast OK on its background | |
| 5 | Brand/palette matches this project's design system; hero still reads without chrome | |
| 6 | First viewport not cluttered | |
| 7 | Primary actions feel tappable on small screens (~44px) | |

## Checklist — additional rendering modes

When the product supports more than one mode for this screen (colour theme, density, high-contrast, RTL, …), the mock must present **every supported mode** behind an in-place control, and run these in addition to 1–7:

| # | Check | Pass? |
|---|---|---|
| M1 | Surfaces that separate in the primary mode still separate in each other mode | |
| M2 | Elevation cues survive (e.g. shadow-only elevation can vanish on near-black — need border or real tonal step) | |
| M3 | Contrast re-checked **per mode** — a muted token that passes on one surface can fail on another | |
| M4 | Section rhythm / emphasis from the primary design survives in each mode | |
| M5 | Brand character remains legible (not a greyscale inversion unless that is the brand) | |
| M6 | Native chrome follows the mode where relevant (`color-scheme`, etc.) | |

### Exempt modes

List screens (or modes) that are **deliberately** not supported here, so “absent” ≠ “forgotten”:

| Screen / mode | Why exempt |
|---|---|
| _e.g. pre-auth funnel — light brand only_ | _…_ |

## Checklist — narrow width

| # | Check | Pass? |
|---|---|---|
| W1 | Reviewed at the **narrowest width the product supports** as well as wide — not only at the reviewer's window width | |
| W2 | No text overlaps; no mid-phrase wraps on primary labels at that width | |
| W3 | Narrow layout is a **strategy**, not a shrink-until-it-fits | |

## Tools (optional, not required)

- Contrast / a11y checkers — only when contrast is uncertain.
- No external “design score” product is part of this gate.

## After the checklist

1. Fix material findings.  
2. Open the mock in the browser for the human — in **every supported mode**.  
3. Iterate on their notes; re-run this checklist each edit round.

## After human approval (implementation)

The approved mock is the **visual** source of truth. Preserve section banding and palette relationships — do not flatten them through semantic theme tokens. Before completing the UI task, open the live page and confirm it still reads like the mock in every supported mode.
