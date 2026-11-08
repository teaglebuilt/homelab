---
name: review-change
description: Independently review a real diff and identify actionable defects.
---

# Review change
1. Fetch the exact PR and base revision; don't trust generated summaries.
2. Review behavior, security, data compatibility, error handling, performance, tests.
3. Give path+line and severity for each supported finding.
4. Report PASS, CHANGES_REQUESTED, or BLOCKED; never merge.
