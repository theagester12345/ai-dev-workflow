# Mockups index

> ⚠️ STARTER — unbootstrapped. After [`../../BOOTSTRAP.md`](../../BOOTSTRAP.md), remove this banner. This directory is gitignored for HTML artifacts in many projects — **this index and `DESIGN_REVIEW.md` stay committed.**

**Canonical gate:** [`../../WORKFLOW.md` → UI mock design self-review](../../WORKFLOW.md#ui-mock-design-self-review--before-human-approval).  
**Checklist Binding:** [`DESIGN_REVIEW.md`](./DESIGN_REVIEW.md).

## Layout

```
mockups/
├── README.md              # this file
├── DESIGN_REVIEW.md       # agent checklist
└── <screen-or-task-id>/
    ├── index.html         # (or equivalent) reviewable mock
    └── README.md          # Screen Intent pointer + Approval: PENDING|APPROVED
```

## Per-task gate (short)

1. Create/update the mock.  
2. Run `DESIGN_REVIEW.md` — fix material fails.  
3. Open in a real browser for the human (every mode the screen supports).  
4. Stamp `Approval: APPROVED` on the section README — **then** edit application source.  
5. Implement as visual SoT; live-check before marking the UI task done.
