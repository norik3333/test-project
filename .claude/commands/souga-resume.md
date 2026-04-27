---
description: Resume a previous session - loads saved state and presents structured briefing
---

# 双雅 Resume

Load the most recent saved session and present a structured briefing. Does NOT start working automatically.

## Usage

```bash
/souga-resume
```

## What It Does

Find and load the latest session file from `.claude/sessions/`, present a structured briefing, and wait for the user's instruction.

## Execution Steps

### Step 0: バナー表示

セッション復元の前に、双雅システム起動バナーを表示する。

**重要: バナーの情報はすべて「双雅システム本体」から取得する。現在の作業プロジェクトの値を使ってはいけない。**

```bash
# SOUGA_REPO を自動検出
if [ -d "/Volumes/外SSD/project/souga system/souga_system" ]; then
  SOUGA_REPO="/Volumes/外SSD/project/souga system/souga_system"
elif [ -d "$HOME/project/souga_system" ]; then
  SOUGA_REPO="$HOME/project/souga_system"
fi
GLOBAL_CLAUDE="$HOME/.claude"
```

1. **バージョン**: `$SOUGA_REPO/packages/cli/package.json` の `version` フィールド（なければ `$SOUGA_REPO/package.json`）
2. **ブランチ**: 現在の作業ディレクトリの `git branch --show-current`
3. **未コミット変更**: 現在の作業ディレクトリの `git status --porcelain`
4. **Agent数**: `$GLOBAL_CLAUDE/agents/` 直下の `.md` ファイル数
5. **Command数**: `$SOUGA_REPO/.claude/commands/` 内の `.md` ファイル数
6. **Skill数**: `$GLOBAL_CLAUDE/skills/` 内の `.md`（README除く）＋ `SKILL.md` を含むディレクトリの合計

```
══════════════════════════════════════════
  双雅（ソウガ）システム v{VERSION} 再開
  Branch: {BRANCH}{DIRTY}
  Agents: {N} | Commands: {N} | Skills: {N}
══════════════════════════════════════════
```

注意: `/souga-start` では「起動」、`/souga-resume` では「再開」と表示する。

### Step 1: Find Latest Session

**必須: ファイルの更新時刻（`ls -t`）は使わない。frontmatter の `date` + `time` で比較すること。**

手順:
1. `.claude/sessions/*.md` を全列挙（`ls .claude/sessions/*.md 2>/dev/null`）
2. 各ファイルの先頭 10 行を読み、`date:` と `time:` を抽出する（`time:` がない場合は `00:00` とする）
3. `{date}T{time}` の文字列で降順ソートし、最上位のファイルを選ぶ
4. 複数候補がある場合はすべての `date:` と `time:` を列挙してから選ぶ

If no session files exist, report:

```
No saved sessions found in .claude/sessions/.
Use /souga-save to save a session first.
```

### Step 2: Read Session File

Read the most recent session file and parse all sections.

### Step 3: Verify Branch

Check if the current branch matches the saved session's branch:

```bash
git branch --show-current
```

If branches differ, warn the user:

```
WARNING: Saved session was on branch 'feature/learning-system'
         but current branch is 'main'.
         Switch branch? [y/n]
```

### Step 4: Present Briefing

Display a structured briefing in this exact format:

```
SESSION BRIEFING
=================
Date: 2026-03-20
Time: 14:32
Branch: feature/learning-system
Issue: #42
Status: in-progress

BUILT:
- Created src/agents/learning-agent.ts
- Added 12 tests in tests/learning-agent.test.ts

FAILED (do not repeat these):
- ESM dynamic import with bare paths -> use pathToFileURL()
- npm audit fix --force -> broke @octokit/rest, pin versions manually
- Jest with ESM -> use vitest instead

LEFT TO DO:
1. [HIGH] Implement confidence scoring
2. [MEDIUM] Add integration tests
3. [LOW] Update documentation

NEXT STEP:
Open src/agents/learning-agent.ts line 45 and implement evaluatePattern().
Run npm test -- tests/learning-agent.test.ts to verify.
=================
Awaiting your instruction.
```


### Step 4b: SEMANTIC MEMORY（Layer B 統合）

セッションの NEXT STEP・issue・branch をクエリとして `souga memory search` を実行し、
関連するファクトを信頼スコア付きで表示する。

```bash
# NEXT STEP のキーワードを簡潔に抽出してクエリ化
QUERY="<NEXT_STEP の最初の 40 文字程度>"
RESULTS=$(souga memory search "$QUERY" --top 8 --json 2>/dev/null)
```

**表示形式**（結果が1件以上ある場合のみ表示。0件またはエラーはスキップ）:

```
SEMANTIC MEMORY  [~/.souga/memories/facts.db]
---------------------------------------------
確実なパターン（trust ≥ 0.7）:
  ● [ファクト内容] (trust: 0.85, cat: tech)

注意・失敗パターン（trust ≤ 0.4）:
  ● [ファクト内容] (trust: 0.25, cat: rule)

中立（0.4 < trust < 0.7）:
  ● [ファクト内容] (trust: 0.55, cat: project)
---------------------------------------------
```

**ルール**:
- `souga memory search` コマンドが使えない場合はこのステップをスキップ
- 結果が 0 件の場合もスキップ（表示しない）
- trust スコアで3グループに分けて表示する
- `--json` フラグで取得した JSON を解析して整形する

### Step 4c: STALENESS CHECK（鵜呑み防止・必須）

**NEXT STEP を提示する前に必ず実行する。**
保存時点と現在時刻の間に main/PR/Issue が動いている可能性を検知する。

```bash
# session frontmatter から保存時刻とブランチを取得
SESSION_TIME="{frontmatter.date}T{frontmatter.time}:00Z"
SESSION_BRANCH="{frontmatter.branch}"

# a) main の最新を取得（ネット失敗は黙ってスキップ）
git fetch origin main --quiet 2>/dev/null || true

# b) HEAD が origin/main から何コミット遅れているか
BEHIND=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)

# c) session 保存後にマージされた PR
RECENT_MERGES=$(gh pr list --state merged --limit 30 \
  --json number,title,mergedAt \
  --jq "[.[] | select(.mergedAt > \"$SESSION_TIME\")] | .[] | \"  #\(.number) \(.title)\"" \
  2>/dev/null)

# d) session 本文で言及された PR/Issue の現在 state
MENTIONED_REFS=$(grep -oE '#[0-9]+' "$SESSION_FILE" | sort -u | head -10)
# 各参照について gh pr view / gh issue view で state を取得して突合
```

**表示ルール**:

- 全て異常なし（BEHIND=0 かつ RECENT_MERGES 空）→ `✓ Staleness check: clean（遅れなし・新規マージなし）` の 1 行のみ
- いずれか異常あり → 下記ブロックを強調表示し、**NEXT STEP の前に**表示する:

```
⚠️ STALENESS DETECTED — NEXT STEP を鵜呑みにしないこと

  Session saved:  {SESSION_TIME} on {SESSION_BRANCH}
  Current HEAD:   {BEHIND} commits behind origin/main

  Merged AFTER this session:
    {RECENT_MERGES}

  Session-mentioned refs（現在 state と照合）:
    #NNN → {state} {差分があれば注記}

  ➜ NEXT STEP は時代遅れの可能性があります。実行前に上記を確認し、
    必要なら別のタスク（新規マージで発生した修正・後続 Issue 等）を先に検討してください。
```

**ルール**:
- `git` / `gh` が使えない場合はこのステップをスキップ（失敗して止めない）
- 警告ありの場合でも自動で止めず、ユーザー判断に委ねる（Step 5 WAIT に入る）
- 閾値は `BEHIND >= 1` or `RECENT_MERGES が 1 件以上`（保守的に、小さな遅れでも必ず通知）

### Step 5: WAIT

**Do NOT start working.** The briefing is informational. Wait for the user to:
- Confirm the next step
- Choose a different task from "LEFT TO DO"
- Change approach
- Ask questions about the previous session

## Loading a Specific Session

If the user wants a specific session (not the latest):

```bash
ls .claude/sessions/
```

List available sessions and let the user choose.

## Related

- `/souga-save` - Save current session state
- `/souga-learn` - Extract patterns from session
- Skill: [session-management](../skills/session-management.md)
