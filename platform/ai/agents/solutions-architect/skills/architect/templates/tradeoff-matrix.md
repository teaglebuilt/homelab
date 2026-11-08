# Architecture Tradeoff Matrix Template

Use this template when comparing 2-3 candidate architectures for a specific decision.

---

## Decision: [What are we deciding?]

### Context
[Brief description of the situation and constraints]

### Candidates

| | Option A: [Name] | Option B: [Name] | Option C: [Name] |
|---|---|---|---|
| **Summary** | [1-2 sentence description] | [1-2 sentence description] | [1-2 sentence description] |
| **Example** | [Real-world system using this] | [Real-world system using this] | [Real-world system using this] |

### Quality Attribute Comparison

*Weight: 1=nice-to-have, 5=critical requirement*
*Score: 1=poor fit, 3=adequate, 5=excellent fit*

| Attribute | Weight | Option A | Option B | Option C |
|-----------|--------|----------|----------|----------|
| Performance | /5 | /5 | /5 | /5 |
| Scalability | /5 | /5 | /5 | /5 |
| Maintainability | /5 | /5 | /5 | /5 |
| Testability | /5 | /5 | /5 | /5 |
| Deployability | /5 | /5 | /5 | /5 |
| Operational complexity | /5 | /5 | /5 | /5 |
| Dev experience | /5 | /5 | /5 | /5 |
| Time to market | /5 | /5 | /5 | /5 |
| Cost (dev + ops) | /5 | /5 | /5 | /5 |
| **Weighted Total** | | **___** | **___** | **___** |

### Key Tradeoffs

| Tradeoff | Option A | Option B | Option C |
|----------|----------|----------|----------|
| **Optimizes for** | [primary quality] | [primary quality] | [primary quality] |
| **Sacrifices** | [what you lose] | [what you lose] | [what you lose] |
| **Biggest risk** | [main concern] | [main concern] | [main concern] |
| **Migration path** | [can we change later?] | [can we change later?] | [can we change later?] |
| **Team readiness** | [can we operate this?] | [can we operate this?] | [can we operate this?] |

### Recommendation

**Recommended: Option [X]**

[2-3 sentences on why, referencing the weights and scores above. Be explicit about what you're trading away and why that's acceptable given the constraints.]

**Dissenting view:** [If reasonable people might disagree, acknowledge the strongest argument for the other option.]

**Review trigger:** [Under what conditions should we revisit this decision? e.g., "If traffic exceeds X", "If team grows beyond N", "In 6 months"]
