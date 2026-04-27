---
description: コードクリーンアップ - デバッグ残骸除去・命名修正・import整理
---

# 双雅 Cleanup

Run みがくん (CleanupAgent) to perform a De-Sloppify pass on the codebase without altering logic.

## Usage

```bash
/souga-cleanup
```

## What It Does

Cleans up code quality issues that do not change runtime behavior:

1. **Remove Debug Artifacts** - Strip `console.log`, completed TODOs, commented-out code
2. **Fix Naming Consistency** - Align with coding-standards.md conventions
3. **Remove Unused Imports/Variables** - Clean dead code references
4. **Check Immutability Patterns** - Flag unnecessary mutations
5. **Report** - List all changes made with file locations

## Execution Steps

### Step 1: Identify Target Files

```bash
CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR HEAD | grep -E '\.(ts|tsx|js|jsx)$' || true)
if [ -z "$CHANGED_FILES" ]; then
  # If no staged changes, scan all source files
  CHANGED_FILES=$(find src packages -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' 2>/dev/null | head -100)
fi
echo "Scanning $(echo "$CHANGED_FILES" | wc -l | tr -d ' ') files"
```

### Step 2: Remove Debug Artifacts

Scan and remove the following patterns:

```bash
for f in $CHANGED_FILES; do
  # console.log / console.debug / console.warn used for debugging
  grep -nE 'console\.(log|debug|warn|info)\(' "$f" 2>/dev/null || true

  # Completed TODOs (marked as DONE or containing checkmarks)
  grep -nE '//\s*(TODO|FIXME|HACK).*\b(done|complete|fixed|resolved)\b' "$f" 2>/dev/null || true

  # Large blocks of commented-out code (3+ consecutive comment lines)
  # Detected by scanning for sequences of // lines that look like code
done
```

Remove `console.log` statements that are clearly debug-only (not in error handlers or logging utilities). Preserve `console.error` and structured logger calls.

### Step 3: Remove Unused Imports and Variables

```bash
# Use TypeScript compiler to detect unused
npx tsc --noEmit --noUnusedLocals --noUnusedParameters 2>&1 | grep -E "is declared but" || true
```

For each unused import or variable:
- Remove unused import specifiers
- Remove entire import line if all specifiers are unused
- Prefix intentionally unused parameters with `_`

### Step 4: Fix Naming Consistency

Check against project conventions:
- **Files**: kebab-case for files, PascalCase for components
- **Variables**: camelCase for variables/functions, PascalCase for classes/types
- **Constants**: UPPER_SNAKE_CASE for true constants
- **Interfaces**: PascalCase, no `I` prefix (use descriptive names)

```bash
for f in $CHANGED_FILES; do
  # Check for inconsistent naming patterns
  grep -nE 'const [A-Z][a-z]+[A-Z].*=' "$f" 2>/dev/null || true  # PascalCase vars
  grep -nE 'interface I[A-Z]' "$f" 2>/dev/null || true              # I-prefixed interfaces
done
```

Report naming issues but only auto-fix within the scope of changed files.

### Step 5: Check Immutability Patterns

Flag mutable patterns that could be immutable:

```bash
for f in $CHANGED_FILES; do
  # let that could be const
  grep -nE '^\s*let\s+\w+\s*=' "$f" 2>/dev/null || true

  # Array mutation methods on what could be immutable data
  grep -nE '\.(push|pop|shift|unshift|splice|sort|reverse)\(' "$f" 2>/dev/null || true

  # Object.assign where spread could be used
  grep -nE 'Object\.assign\(' "$f" 2>/dev/null || true
done
```

Auto-fix `let` -> `const` only when the variable is never reassigned. Report other patterns as suggestions.

## Output

Print a structured cleanup report:

```
CLEANUP REPORT (みがくん)
==========================
Files Scanned:     15
Changes Made:      8
==========================
REMOVED:
  - src/agent.ts:23      console.log("debug data")
  - src/agent.ts:67      // TODO: done - remove this
  - src/utils.ts:5       import { unused } from './types'
FIXED:
  - src/config.ts:12     let -> const (never reassigned)
  - src/handler.ts:3     Removed unused import 'Response'
SUGGESTIONS (not auto-fixed):
  - src/data.ts:45       Array.push() -> spread operator
  - src/model.ts:8       interface IUser -> User
==========================
Logic Changes: NONE (safe De-Sloppify pass)
```

## Safety Rules

- **NEVER alter runtime logic** - only cosmetic and dead-code changes
- **NEVER remove `console.error`** or structured logger calls
- **NEVER rename exported symbols** - only local variables and private members
- **NEVER modify test assertions** - only clean up test helper code
- **Preserve all JSDoc/TSDoc comments** - only remove stale inline comments
- Run `npm run build` after cleanup to verify nothing broke
- Run `npm test -- --run` after cleanup to verify tests still pass

## Post-Cleanup Verification

```bash
npm run build
npm test -- --run
```

If either fails, **revert all changes** and report which cleanup caused the failure.

## When to Use

- Before creating a PR (final polish pass)
- After a large feature implementation
- During code review when reviewer requests cleanup
- Periodic codebase hygiene

## Related

- `/souga-verify` - Full verification pipeline
- `/souga-build-fix` - Fix build errors (run this first if build is broken)
- Agent spec: `.claude/agents/specs/coding/cleanup-agent.md`
