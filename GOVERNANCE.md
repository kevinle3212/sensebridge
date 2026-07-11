# Governance

## Model: Benevolent Dictator (for now)

SenseBridge is currently maintained by one person, Kevin Khanh Le
(`kevinle3212@gmail.com`), who makes final decisions on scope, architecture,
and releases. This is stated openly rather than dressed up as a committee,
because pretending otherwise would be less honest and less useful to
contributors trying to understand how decisions actually get made.

This is expected to evolve. As sustained contributors arrive, decision-making
is expected to move toward a small maintainer group, with the current
maintainer proposing that transition rather than waiting to be asked.

## How decisions get made today

- Product scope and architecture calls: maintainer decides, informed by
  [`docs/roadmap.md`](docs/roadmap.md) and open issues/discussions.
- Code changes: reviewed against [`CONTRIBUTING.md`](CONTRIBUTING.md) and
  [`docs/accessibility.md`](docs/accessibility.md); accessibility regressions
  are treated as release blockers, not style nits.
- Anything touching biometric data, safety-adjacent phrasing, or model
  licensing (see [`docs/ai-models.md`](docs/ai-models.md)): maintainer
  decides, consulting counsel where the plan's legal notes call for it.

## Bus-factor plan

The single biggest governance risk in a solo project is that it dies if the
maintainer stops. Mitigations:

- Documentation is treated as a first-class deliverable, not an afterthought
  — see [`docs/`](docs) — so someone else could pick the project up.
- Architecture decisions are recorded as they're made in
  [`docs/adr/`](docs/adr), with the reasoning, not just the outcome.
- If the project grows real usage or a contributor base, a fiscal sponsor
  (for example, [Software Freedom Conservancy](https://sfconservancy.org/) or
  [NumFOCUS](https://numfocus.org/)) is worth pursuing for both funding and
  institutional continuity beyond any one person.

## Changing this document

Propose changes to governance the same way as any other change: an issue or
PR, discussed in the open.
