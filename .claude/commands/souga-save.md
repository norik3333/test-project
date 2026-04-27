---
description: セッション保存 - 進捗・成功・失敗・次のステップを記録
---

# 双雅 Save

Capture comprehensive session state and save to `.claude/sessions/`.

## Usage

```bash
/souga-save
```

## What It Does

Analyze the current session and save a structured state file that enables seamless resumption later. The most important section is "What did NOT work" -- this prevents the next session from repeating failed approaches.

## Execution Steps

### Step 1: Create Sessions Directory

```bash
mkdir -p .claude/sessions
```

### Step 2: Gather Context

Collect the following information from the current session:

1. **Branch**: `git branch --show-current`
2. **Related Issue**: Check recent commits and conversation for issue references
3. **Changed Files**: `git diff --name-only HEAD` and `git status --short`

### Step 3: Build Session Document

Construct the session file with ALL of these sections:

```markdown
---
date: [today's date]
time: [HH:MM]
session_id: [short unique id]
branch: [current branch]
issue: [related issue number if any]
status: in-progress | blocked | ready-for-review
decision_log: [.claude/decision-logs/YYYY-MM-DD.jsonl またはなければ空]
saved_path: [absolute path to this file e.g. /path/to/.claude/sessions/YYYY-MM-DD-<id>.md]
---

# Session: [brief description of what this session was about]

## What Was Built
- [concrete deliverable 1]
- [concrete deliverable 2]

## What Worked
- [approach/technique that succeeded and why]

## What Did NOT Work
- [failed approach 1] -> [why it failed] -> [what was done instead]
- [failed approach 2] -> [why it failed] -> [what was done instead]

## What Is Left
1. [HIGH] [remaining task 1]
2. [MEDIUM] [remaining task 2]
3. [LOW] [remaining task 3]

## Key Decisions
- [decision]: [rationale]

## Exact Next Step
[One specific, actionable instruction. Not vague. Include file paths,
line numbers, function names, and the exact command to run for verification.]
```

### Step 4: Present for Review

Show the session document to the user before saving. The user may want to adjust or add information.

### Step 4b: agent-track.yml 自動更新

**このステップは必須。スキップ禁止。**

セッション文書（Step 3で作成した内容）を元に、`.claude/agent-track.yml` を更新する。

---

#### 4b-1: Agent実績を抽出する

作成したセッション文書の「What Worked」「What Did NOT Work」セクションを読み、以下のルールで対象Agentを特定する。

**成功カウント対象の検出パターン**（いずれかに該当する行）:
- 「{Agent名} completed」「{Agent名} succeeded」「{Agent名} が完了」
- 「{Agent名} → 成功」「{Agent名} を実行 → 動作確認済み」
- 「What Worked」セクションで {Agent名} が登場し、肯定的な文脈がある
- `/souga-orchestrate` の実行で {Agent名} が実際にタスクを完了した

**失敗カウント対象の検出パターン**（いずれかに該当する行）:
- 「{Agent名} failed」「{Agent名} エラー」「{Agent名} が詰まった」
- 「{Agent名} → 失敗」「{Agent名} → スキップ」
- 「What Did NOT Work」セクションで {Agent名} が登場する

**Agent名の表記ゆれ対応**（以下はすべて同一として扱う）:

| 表記例 | YAMLキー名 |
|--------|-----------|
| CodeGenAgent / code-gen-agent / コード生成Agent | CodeGenAgent |
| SecurityAgent / security-agent / セキュリティAgent | SecurityAgent |
| ReviewAgent / review-agent / レビューAgent | ReviewAgent |
| PRAgent / pr-agent / PR作成Agent | PRAgent |
| IssueAgent / issue-agent | IssueAgent |
| DeploymentAgent / deployment-agent / デプロイAgent | DeploymentAgent |
| CoordinatorAgent / coordinator-agent | CoordinatorAgent |
| PathDesignAgent / path-design-agent / 道設計Agent | PathDesignAgent |
| RiskAssessorAgent / risk-assessor-agent | RiskAssessorAgent |
| ECC: architect / architect agent / アーキテクトAgent | ECC_architect |
| ECC: tdd-guide / tdd-guide / TDD Agent | ECC_tdd-guide |
| ECC: code-reviewer / code-reviewer / コードレビューAgent | ECC_code-reviewer |
| Superpowers: brainstorming / brainstorming | Superpowers_brainstorming |
| Superpowers: writing-plans / writing-plans | Superpowers_writing-plans |
| Superpowers: quality-gate / quality-gate | Superpowers_quality-gate |

---

#### 4b-2: agent-track.yml を読む

```bash
cat .claude/agent-track.yml
```

ファイルが存在しない場合: `.claude/agent-track.yml` を新規作成し、必要なエントリを追加する。

---

#### 4b-3: 値を更新する

4b-1で特定したAgentについて、Read + Edit ツールで以下を行う:

**成功の場合**: 該当Agentの `success:` の値を +1 し、`last_updated:` を今日の日付（`YYYY-MM-DD`）に更新する。

**失敗の場合**: 該当Agentの `failure:` を +1、`failure_patterns:` に失敗内容を1行追記（重複は追加しない）、`last_updated:` を今日の日付に更新する。`failure:` キーが存在しないエントリの場合は `failure: 1` を追記してから更新する。

**該当Agentのエントリがない場合**: ファイル末尾に新規追加する:
```yaml
NewAgentName:
  success: 1
  failure: 0
  failure_patterns: []
  last_updated: "YYYY-MM-DD"
```

---

#### 4b-4: 完了確認

更新後に以下を出力して次のステップへ進む:

```
agent-track.yml 更新完了:
  成功 +1: {Agent名リスト（なければ「なし」）}
  失敗 +1: {Agent名リスト（なければ「なし」）}
```

更新対象のAgentが1件もない場合は「agent-track.yml 更新対象なし（今回のセッションでAgent実行なし）」と出力して次へ進む。

### Step 5: Save

Save to `.claude/sessions/YYYY-MM-DD-<id>.md`.

```
SESSION SAVED
==============
File: .claude/sessions/2026-03-20-abc123.md
Branch: feature/learning-system
Status: in-progress
Next step captured: Yes
Failures documented: 3
==============
```

## Key Rules

1. **Never skip "What Did NOT Work"** -- This is the highest-value section. If nothing failed, explicitly write "No failures encountered."
2. **"Exact Next Step" must be actionable** -- Bad: "Continue implementation." Good: "Open `src/agents/learning-agent.ts` line 45 and implement `evaluatePattern()`. Run `npm test -- tests/learning-agent.test.ts` to verify."
3. **Include enough detail to resume without re-reading code** -- The next session starts cold. Every piece of context that would require re-investigation should be in this file.

## Related

- `/souga-resume` - Resume a saved session
- `/souga-learn` - Extract reusable patterns before saving
- Skill: [session-management](../skills/session-management.md)
