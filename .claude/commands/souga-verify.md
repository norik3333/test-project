---
description: 6フェーズ検証パイプライン - ビルド・型・Lint・テスト・セキュリティ・差分
---

# 双雅 Verify

Run the 6-phase verification loop to validate completion before PR creation.

This command invokes the `verification-loop` skill to enforce HARD-GATE 6.

## Usage

```bash
/souga-verify
```

## What It Does

Execute all 6 verification phases in sequence, stopping at first failure:

1. **Build Check** - `npm run build` must succeed
2. **Type Check** - `npx tsc --noEmit` must produce zero errors
3. **Lint Check** - ESLint on changed files, no critical violations
4. **Test Suite** - `npm test -- --run --coverage`, all pass, coverage >= 80%
5. **Security Scan** - No hardcoded secrets or dangerous patterns in diff
6. **Diff Review** - `git diff --stat` confirms scoped, clean changes

## Execution Steps

### Step 1: Run Build

```bash
npm run build
```

If this fails, report the build errors and stop.

### Step 2: Run Type Check

```bash
npx tsc --noEmit
```

If this fails, report the type errors and stop.

### Step 3: Run Lint on Changed Files

```bash
CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR HEAD | grep -E '\.(ts|tsx|js|jsx)$' || true)
if [ -n "$CHANGED_FILES" ]; then
  npx eslint $CHANGED_FILES
fi
```

If this fails, report the lint errors and stop.

### Step 4: Run Tests with Coverage

```bash
npm test -- --run --coverage
```

If tests fail or coverage is below 80%, report and stop.

### Step 5: Security Scan

```bash
git diff HEAD --unified=0 | grep -iE '(api[_-]?key|secret|password|token)\s*[:=]\s*["\x27][A-Za-z0-9]' || true
npm audit --audit-level=high 2>/dev/null || true
```

If hardcoded secrets are found, report and stop.

### Step 6: Diff Review

```bash
git diff --stat HEAD~1
git diff --name-only HEAD~1 | grep -E '\.(env|pem|key|log)$' || true
```

Review the output for scope creep or unintended changes.

## Output

Print a structured verification report:

```
VERIFICATION REPORT
===================
Phase 1: Build       PASS/FAIL
Phase 2: TypeCheck   PASS/FAIL
Phase 3: Lint        PASS/FAIL (N warnings)
Phase 4: Tests       PASS/FAIL (N passed, N skipped)
Phase 5: Security    PASS/FAIL
Phase 6: Diff Review PASS/FAIL (N files changed)
===================
VERDICT: READY FOR PR / BLOCKED - [reason]
```

## When to Use

- Before creating a PR
- Before marking an Issue as done
- After ReviewAgent requests re-verification
- As part of `/deploy` pre-flight

## Related

- `/verify` - Basic system health check (environment, compile, test)
- `/deploy` - Full deployment pipeline (includes verification)
- `/security-scan` - Detailed security audit
- Skill: [verification-loop](../skills/verification-loop.md)
