# Governance

## Model: Benevolent Dictator

SenseBridge is currently maintained by one person, Kevin K. Le
(`kevinle3212@gmail.com`), who makes final decisions on scope, architecture,
and releases. This is stated openly rather than dressed up as a committee,
because pretending otherwise would be less honest and less useful to
contributors trying to understand how decisions actually get made.

This is expected to evolve. As sustained contributors arrive, decision-making
is expected to move toward a small maintainer group, with the current
maintainer proposing that transition rather than waiting to be asked.

## How decisions get made today

- Product scope and architecture calls: maintainer decides, informed by
  [`docs/ROADMAP.md`](docs/ROADMAP.md) and open issues/discussions.
- Code changes: reviewed against [`CONTRIBUTING.md`](CONTRIBUTING.md) and
  [`docs/ACCESSIBILITY.md`](docs/ACCESSIBILITY.md); accessibility regressions
  are treated as release blockers, not style nits.
- Anything touching biometric data, safety-adjacent phrasing, or model
  licensing (see [`docs/AI-MODELS.md`](docs/AI-MODELS.md)): maintainer
  decides, consulting counsel where the plan's legal notes call for it.

## Bus-factor plan

The single biggest governance risk in a solo project is that it dies if the
maintainer stops. Mitigations:

- Documentation is treated as a first-class deliverable, not an afterthought
  — see [`docs/`](docs) — so someone else could pick the project up.
- Architecture decisions should be recorded as they're made, with the
  reasoning, not just the outcome — a dedicated `docs/adr/` directory doesn't
  exist yet; today `docs/ARCHITECTURE.md` and inline doc comments carry that
  reasoning instead.
- If the project grows real usage or a contributor base, a fiscal sponsor
  (for example, [Software Freedom Conservancy](https://sfconservancy.org/) or
  [NumFOCUS](https://numfocus.org/)) is worth pursuing for both funding and
  institutional continuity beyond any one person.

## Changing this document

Propose changes to governance the same way as any other change: an issue or
PR, discussed in the open.

---

Need help? See [`SUPPORT.md`](SUPPORT.md).
