# Architecture Decision Record Template

An ADR records **why** a decision was made, for the person who inherits it — most
often a future version of the author who no longer remembers the constraints.
That makes the reasoning the payload; the decision itself is usually the shortest
section.

Save as `docs/adr/NNNN-short-kebab-description.md`, numbered sequentially and
never renumbered. Superseding an ADR means writing a new one that links back, not
editing the old one — the record of what was believed at the time is the point.

---

```markdown
# NNNN. [Short present-tense title, e.g. "Use Postgres for the event store"]

- **Status:** Proposed | Accepted | Deprecated | Superseded by [ADR-NNNN](./NNNN-....md)
- **Date:** YYYY-MM-DD
- **Deciders:** [names or roles]
- **Tags:** [data, deployment, security, ...]

## Context

What situation forces a decision now? Cover the constraints that are actually
binding — team size and skills, existing systems, deadlines, compliance, budget,
expected scale. Include the numbers you have; "high traffic" ages badly in a way
that "~3k req/s peak, 40GB/day ingest" does not.

State what is *not* in scope, so a later reader doesn't assume the decision
covered more ground than it did.

## Decision Drivers

The criteria the options are judged against, most important first. These are the
quality attributes that matter for this decision specifically — three to five of
them, not a generic list.

- [Driver 1, e.g. "Recovery must be point-in-time to any moment in the last 30 days"]
- [Driver 2]
- [Driver 3]

## Considered Options

1. **[Option A]** — one-line summary
2. **[Option B]** — one-line summary
3. **[Option C]** — one-line summary

Include the option that was rejected early. An ADR listing only the winner and
one strawman reads as justification rather than analysis, and it fails the reader
who arrives later wondering "did anyone consider X?"

### [Option A]

- **How it works:** [brief]
- **Good:** [what it wins on, tied to the drivers above]
- **Bad:** [what it costs]
- **Evidence:** [prior art, benchmark, tree document, production experience]

### [Option B]

_(same structure)_

## Decision Outcome

**Chosen: [Option X]**

Because [the reasoning that connects the drivers to this option — this is the
sentence the whole document exists to hold].

### Consequences

**Positive**
- [What gets easier or cheaper]

**Negative**
- [What gets harder, slower, or more expensive — an ADR with no negative
  consequences has not been thought through, since every choice trades something]

**Neutral / follow-on work**
- [Migrations, new operational burden, monitoring to add, decisions now deferred]

### Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| [What could go wrong] | Low/Med/High | Low/Med/High | [What reduces it] |

## Validation

How will anyone know this decision was right — or catch it being wrong early?

- **Fitness function / guardrail:** [an automated check that protects the intent,
  e.g. a dependency-direction lint, a latency budget in CI]
- **Signals to watch:** [metrics, error classes, cost lines]
- **Revisit when:** [the concrete trigger that should reopen this — a scale
  threshold, a team-size change, a dependency's EOL date]

## References

- [Tree documents consulted, cited by `tree/<path>.md`]
- [Related ADRs]
- [External docs, RFCs, benchmarks]
```

---

## Writing notes

**Title in the present tense, as an instruction.** "Use Postgres for the event
store", not "Postgres was chosen" or "Event store decision". Scanning a directory
of ADR titles should read as a list of the system's standing commitments.

**Write Context before you know the answer.** Context written after the decision
tends to be reverse-engineered into a justification for it, which destroys the
document's value as a record.

**Keep it to one decision.** If Context needs two unrelated paragraphs, it is two
ADRs. Bundled decisions can't be superseded independently later.

**Length follows stakes.** A one-way door that shapes the next two years earns
several pages. A reversible library choice earns half of one. Padding a small
decision into the full template trains people to skim ADRs.

**Status changes, content doesn't.** When a decision is reversed, mark this one
`Superseded by ADR-NNNN` and leave the body as it was written.
