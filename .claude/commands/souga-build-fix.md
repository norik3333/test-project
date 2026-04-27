---
description: ビルドエラー自動修正 - エラーを1つずつ安全に修復
---

# 双雅 Build Fix

Run なおすん (BuildFixAgent) to automatically detect and fix build errors iteratively.

## Usage

```bash
/souga-build-fix
```

## What It Does

Detects the build system, runs the build, and fixes errors one at a time with verification after each fix:

1. **Detect Build System** - Identify npm/yarn/pnpm and build command
2. **Run Initial Build** - Capture baseline error count
3. **Fix Loop** - Fix one error at a time, re-verify after each
4. **Stop Conditions** - Stop on success or after 3 consecutive failures
5. **Summary** - Show before/after error count

## Execution Steps

### Step 1: Detect Build System

```bash
if [ -f "pnpm-lock.yaml" ]; then
  PKG_MGR="pnpm"
elif [ -f "yarn.lock" ]; then
  PKG_MGR="yarn"
else
  PKG_MGR="npm"
fi

# Detect build command from package.json
BUILD_CMD="$PKG_MGR run build"
if grep -q '"build:ts"' package.json 2>/dev/null; then
  BUILD_CMD="$PKG_MGR run build:ts"
fi

echo "Detected: $PKG_MGR | Build command: $BUILD_CMD"
```

### Step 2: Run Initial Build and Capture Errors

```bash
$BUILD_CMD 2>&1 | tee /tmp/souga-build-output.txt
INITIAL_EXIT=$?
INITIAL_ERRORS=$(grep -cE '(error TS|Error:|ERROR|fatal error)' /tmp/souga-build-output.txt || echo "0")
echo "Initial build: exit=$INITIAL_EXIT errors=$INITIAL_ERRORS"
```

If the build succeeds (exit 0), report success and stop.

### Step 3: Iterative Fix Loop

For each iteration (max 10 iterations, max 3 consecutive failures):

1. **Parse the first error** from the build output
2. **Identify the file and line** from the error message
3. **Read the relevant code** around the error location
4. **Apply a targeted fix** for that single error
5. **Re-run the build** to verify the fix worked
6. **Track progress** - if error count decreased, reset failure counter

```
CONSECUTIVE_FAILURES=0
MAX_CONSECUTIVE=3
MAX_ITERATIONS=10
ITERATION=0

while [ $CONSECUTIVE_FAILURES -lt $MAX_CONSECUTIVE ] && [ $ITERATION -lt $MAX_ITERATIONS ]; do
  ITERATION=$((ITERATION + 1))

  # 1. Read first error from build output
  # 2. Fix the identified issue
  # 3. Re-run build
  # 4. Compare error count

  if [ $NEW_ERRORS -ge $PREV_ERRORS ]; then
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
  else
    CONSECUTIVE_FAILURES=0
  fi
done
```

### Step 4: Type Check Verification

After build fixes, also verify types:

```bash
npx tsc --noEmit 2>&1 | tee /tmp/souga-typecheck-output.txt
TYPE_ERRORS=$(grep -c 'error TS' /tmp/souga-typecheck-output.txt || echo "0")
echo "Type errors remaining: $TYPE_ERRORS"
```

## Output

Print a structured fix report:

```
BUILD FIX REPORT (なおすん)
============================
Build System:     npm | npm run build
Initial Errors:   12
Fixes Applied:    9
Final Errors:     3
Iterations:       10
Consecutive Fails: 0
============================
FIXES APPLIED:
  1. src/agent.ts:45 - Added missing import for AgentConfig
  2. src/utils.ts:12 - Fixed type mismatch string -> number
  3. ...
============================
STATUS: IMPROVED (12 -> 3 errors) / FIXED (0 errors) / STUCK (3 consecutive failures)
```

## Stop Conditions

- **SUCCESS**: Build exits with code 0 and zero errors
- **MAX FAILURES**: 3 consecutive fix attempts that do not reduce error count
- **MAX ITERATIONS**: 10 total fix attempts reached
- **WORSE**: Error count increased after a fix (revert and count as failure)

## Safety Rules

- Fix only **one error per iteration** to isolate changes
- **Never modify test files** unless the error is in a test file
- **Never delete code** - only modify, add imports, fix types
- If a fix increases errors, **revert it** before continuing
- Do not modify `.claude/`, `.github/`, or config files unless they caused the error

## When to Use

- After `npm run build` fails
- Before running `/souga-verify`
- After merging branches with conflicts
- When CI reports build failures

## Related

- `/souga-verify` - Full verification pipeline (Build is Phase 1)
- `/test` - Run test suite
- Agent spec: `.claude/agents/specs/coding/buildfix-agent.md`
