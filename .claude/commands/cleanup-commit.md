# cleanup-commit

Step-by-step agent guide for cleaning up code, resolving lint errors, and
committing changes correctly in TrustLedger.

---

## Overview

Four phases in order:

1. Run all linters and collect every error
2. Auto-fix what can be fixed automatically
3. Manually resolve remaining errors
4. Commit with a Conventional Commits message and let hooks verify it

Do not skip phases or commit before all linters exit clean.
