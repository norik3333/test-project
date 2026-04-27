---
description: セキュリティスキャン - OWASP Top 10・シークレット検出・依存関係監査
---

# 双雅 Security

Run まもるん (SecurityAgent) to perform a comprehensive security scan on changed files.

## Usage

```bash
/souga-security
```

## What It Does

Scans the current working tree for security vulnerabilities, focusing on changed files:

1. **OWASP Top 10 Scan** - Check changed files for common vulnerability patterns
2. **Hardcoded Secrets Detection** - Find API keys, tokens, passwords in source
3. **SQL Injection Check** - Detect unsafe query construction
4. **XSS Check** - Find unescaped user input in templates/JSX
5. **npm Audit** - Run dependency vulnerability scan
6. **Severity Report** - Classify all findings by severity level

## Execution Steps

### Step 1: Identify Changed Files

```bash
CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR HEAD | grep -E '\.(ts|tsx|js|jsx|json)$' || true)
if [ -z "$CHANGED_FILES" ]; then
  echo "No changed source files to scan."
fi
```

### Step 2: Hardcoded Secrets Detection

```bash
git diff HEAD --unified=0 | grep -inE '(api[_-]?key|secret[_-]?key|password|token|private[_-]?key|auth[_-]?token)\s*[:=]\s*["\x27][A-Za-z0-9+/]' || true
git diff HEAD --unified=0 | grep -inE '(ghp_|sk-|pk_|AKIA|xox[bsp]-)[A-Za-z0-9]' || true
```

If any matches are found, classify as **CRITICAL**.

### Step 3: SQL Injection Patterns

Scan changed files for unsafe query construction:

```bash
for f in $CHANGED_FILES; do
  grep -nE '(query|execute|raw)\s*\(\s*[`"'"'"'].*\$\{' "$f" 2>/dev/null || true
  grep -nE 'SELECT.*\+\s*(req\.|params\.|query\.|body\.)' "$f" 2>/dev/null || true
done
```

If found, classify as **HIGH**.

### Step 4: XSS Patterns

Scan changed files for unescaped output and unsafe DOM manipulation:

```bash
for f in $CHANGED_FILES; do
  grep -nE 'innerHTML\s*=' "$f" 2>/dev/null || true
  grep -nE 'v-html\s*=' "$f" 2>/dev/null || true
  grep -nE 'document\.write\(' "$f" 2>/dev/null || true
  # Also detect React unsafe HTML injection patterns
  grep -nE 'dangerously' "$f" 2>/dev/null || true
done
```

If found, classify as **HIGH**.

### Step 5: OWASP Top 10 Pattern Scan

Check for additional common vulnerabilities:

```bash
for f in $CHANGED_FILES; do
  # Insecure deserialization
  grep -nE '(eval|Function)\s*\(' "$f" 2>/dev/null || true
  # Insecure crypto
  grep -nE '(md5|sha1)\s*\(' "$f" 2>/dev/null || true
  # Insecure randomness for security-sensitive operations
  grep -nE 'Math\.random\(\)' "$f" 2>/dev/null | grep -iE '(token|secret|key|password|auth|session)' || true
  # Open redirect
  grep -nE 'redirect\s*\(\s*(req\.|params\.|query\.)' "$f" 2>/dev/null || true
  # Path traversal
  grep -nE '(readFile|readFileSync|createReadStream)\s*\(.*\+' "$f" 2>/dev/null || true
done
```

Classify `eval`/`Function` as **HIGH**, others as **MEDIUM**.

### Step 6: npm Audit

```bash
npm audit --audit-level=moderate 2>/dev/null || true
npm audit --json 2>/dev/null | node -e "
  const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  const v = data.metadata?.vulnerabilities || {};
  console.log('critical:', v.critical || 0);
  console.log('high:', v.high || 0);
  console.log('moderate:', v.moderate || 0);
  console.log('low:', v.low || 0);
" 2>/dev/null || true
```

## Output

Print a structured security report:

```
SECURITY SCAN REPORT (まもるん)
================================
Hardcoded Secrets:   N found   [CRITICAL/PASS]
SQL Injection:       N found   [HIGH/PASS]
XSS Patterns:        N found   [HIGH/PASS]
OWASP Patterns:      N found   [HIGH/MEDIUM/PASS]
npm Audit:           N vulns   [CRITICAL/HIGH/MEDIUM/LOW/PASS]
================================
CRITICAL: N  HIGH: N  MEDIUM: N  LOW: N
VERDICT: CLEAN / BLOCKED - CRITICAL findings must be resolved before PR
```

## PR Blocking Rules

- **CRITICAL** findings (hardcoded secrets, critical npm vulns) -> **BLOCK PR**
- **HIGH** findings -> Warn, require justification comment in PR
- **MEDIUM/LOW** findings -> Report only, do not block

## When to Use

- Before creating a PR (runs automatically as part of `/souga-verify`)
- After adding new dependencies
- When modifying auth, input handling, or data access code
- Periodic security review of the codebase

## Related

- `/souga-verify` - Full verification pipeline (includes security as Phase 5)
- `/security-scan` - Legacy security audit command
- Agent spec: `.claude/agents/specs/coding/security-agent.md`
