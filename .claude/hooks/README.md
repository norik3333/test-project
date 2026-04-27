# Claude Code Hooks

## 概要

`.claude/hooks/`には、Claude Code実行時やGit操作時に自動実行されるフックスクリプトが含まれています。

**5種類のフック:**
- **quality-gate.sh** - PostToolUse品質ゲート（双雅システム Phase 1）
- **auto-format.sh** - ESLint/Prettier自動フォーマット
- **validate-typescript.sh** - TypeScript型チェック
- **log-commands.sh** - コマンドログ記録（LDD準拠）
- **agent-event.sh** - Agent実行イベント送信

---

## 利用可能なHook

### 1. `quality-gate.sh` ✅ (双雅 Phase 1)

Edit/Write後に自動で型チェック・ESLintを実行する品質ゲートフックです。

**機能:**
- TypeScript型チェック（`npx tsc --noEmit`）
- ESLintチェック（設定がある場合）
- 対象ファイルのエラーのみ抽出（file:line形式で表示）
- 3プロファイル対応（`SOUGA_PROFILE`環境変数で切替）
- 5秒タイムアウト（軽量実行）

**プロファイル:**

| Profile | 動作 | 終了コード |
|---------|------|-----------|
| `minimal` | チェックをスキップ | 常に0 |
| `standard`（デフォルト） | 警告表示のみ | 常に0 |
| `strict` | エラー時ブロック | エラーあり: 2, なし: 0 |

**使用方法:**
```bash
# Claude Code PostToolUseフックとして設定
# .claude/settings.local.json:
{
  "hooks": {
    "PostToolUse": ".claude/hooks/quality-gate.sh"
  }
}

# プロファイル切替
export SOUGA_PROFILE=strict   # エラー時ブロック
export SOUGA_PROFILE=standard # 警告のみ（デフォルト）
export SOUGA_PROFILE=minimal  # スキップ

# 手動実行
./.claude/hooks/quality-gate.sh Edit path/to/file.ts
```

**出力例（standard、エラーあり）:**
```
[quality-gate] profile=standard file=coordinator.ts
  tsc: 2 type error(s) in src/agents/coordinator.ts
    src/agents/coordinator.ts(42,5): error TS2345: Argument of type 'string' is not assignable to parameter of type 'number'.
  eslint: OK
[quality-gate] 2 total violation(s) found
[quality-gate] warnings only (profile=standard). Set SOUGA_PROFILE=strict to block.
```

**出力例（strict、エラーあり）:**
```
[quality-gate] profile=strict file=coordinator.ts
  tsc: 1 type error(s) in src/agents/coordinator.ts
    src/agents/coordinator.ts(42,5): error TS2345: ...
  eslint: OK
[quality-gate] 1 total violation(s) found
[quality-gate] BLOCKING - strict mode rejects 1 violation(s)
```

---

### 2. `auto-format.sh` ✅

コミット前に自動的にESLint/Prettierを実行し、コードをフォーマットします。

**機能:**
- ESLintによるコード検査と自動修正
- Prettierによるコードフォーマット
- ステージングされたファイルのみ処理
- 修正不能なエラーがある場合はコミット中断

**使用方法:**
```bash
# Git pre-commitフックとして登録
ln -s ../../.claude/hooks/auto-format.sh .git/hooks/pre-commit

# 手動実行
./.claude/hooks/auto-format.sh
```

**出力例:**
```
🔧 Auto-format hook running...
📝 Found 5 files to check

🔍 Running ESLint...
✅ ESLint passed

✨ Running Prettier...
✅ Prettier formatting complete

📦 Re-staging formatted files...
✅ Auto-format complete - ready to commit
```

---

### 3. `validate-typescript.sh` ✅

TypeScriptコンパイルエラーをチェックし、型エラーがある場合はコミットを中断します。

**機能:**
- TypeScript型チェック（strict mode準拠）
- コンパイルエラーの詳細表示
- エラーがある場合はコミット中断

**使用方法:**
```bash
# Git pre-commitフックとして登録
ln -s ../../.claude/hooks/validate-typescript.sh .git/hooks/pre-commit

# 手動実行
./.claude/hooks/validate-typescript.sh
```

**出力例（成功時）:**
```
🔍 TypeScript validation hook running...
📝 Found 8 TypeScript files

🔧 Running TypeScript compiler (tsc --noEmit)...

✅ TypeScript validation passed - all types are correct
```

**出力例（エラー時）:**
```
🔍 TypeScript validation hook running...
📝 Found 8 TypeScript files

🔧 Running TypeScript compiler (tsc --noEmit)...

❌ TypeScript validation failed

╔═══════════════════════════════════════════════════════════════╗
║               TypeScript Compilation Errors Found            ║
╚═══════════════════════════════════════════════════════════════╝

Total Errors: 3

First errors:
src/agents/coordinator.ts:42:5 - error TS2345: Argument of type 'string' is not assignable to parameter of type 'number'.

How to fix:
  1. Review the errors above
  2. Fix type errors in your TypeScript files
  3. Run 'npm run typecheck' to verify fixes
  4. Re-stage your files with 'git add'
```

---

### 4. `log-commands.sh` ✅

Claude Codeコマンドを`.ai/logs/`に記録します（LDD準拠）。

**機能:**
- 日次ログファイル生成（`YYYY-MM-DD.md`形式）
- タイムスタンプ付きコマンド記録
- codex_prompt_chain形式対応

**使用方法:**
```bash
# Claude Code hooks設定に追加
# .claude/settings.local.json:
{
  "hooks": {
    "userPromptSubmit": ".claude/hooks/log-commands.sh"
  }
}

# 手動実行
./.claude/hooks/log-commands.sh "your command here"
```

**ログファイル例（`.ai/logs/2025-10-12.md`）:**
```markdown
# Log-Driven Development Log - 2025-10-12

**Device**: MacBook-Pro
**Project**: Autonomous-Operations
**Date**: 2025-10-12

---

## codex_prompt_chain

**intent**:
**plan**:
**implementation**:
**verification**:

## tool_invocations

### [2025-10-12T03:15:00Z]
- **command**: `npm run agents:parallel:exec -- --issues=270`
- **workdir**: `/Users/shunsuke/Dev/Autonomous-Operations`
- **status**: running
- **notes**: Command executed via Claude Code
```

---

### 5. `agent-event.sh` ✅

Agent実行イベントをダッシュボードにリアルタイム送信します。

**使用方法:**
```bash
./agent-event.sh <event_type> <agent_id> <issue_number> [options]
```

**イベントタイプ:**

| Type | Description | Usage |
|------|-------------|-------|
| `started` | Agent開始 | `./agent-event.sh started coordinator 47` |
| `progress` | 進捗更新 | `./agent-event.sh progress codegen 58 50 "Generating code..."` |
| `completed` | 完了 | `./agent-event.sh completed review 47 '{"success":true}'` |
| `error` | エラー | `./agent-event.sh error issue 47 "Failed to parse"` |

---

## Agent IDリスト

| Agent ID | Name | Description |
|----------|------|-------------|
| `coordinator` | CoordinatorAgent | タスク統括・DAG分解 |
| `codegen` | CodeGenAgent | AI駆動コード生成 |
| `review` | ReviewAgent | コード品質レビュー |
| `issue` | IssueAgent | Issue分析・ラベリング |
| `pr` | PRAgent | Pull Request作成 |
| `deployment` | DeploymentAgent | CI/CDデプロイ |
| `test` | TestAgent | テスト実行 |

---

## TypeScriptからの使用

### 基本的な使用

```typescript
import {
  emitAgentStarted,
  emitAgentProgress,
  emitAgentCompleted,
  emitAgentError,
} from '../scripts/dashboard-events.js';

async function executeAgent(issueNumber: number) {
  await emitAgentStarted('coordinator', issueNumber);

  try {
    // ... agent logic
    await emitAgentProgress('coordinator', issueNumber, 50, 'Processing...');

    // ... more logic
    await emitAgentCompleted('coordinator', issueNumber, { success: true });
  } catch (error) {
    await emitAgentError('coordinator', issueNumber, error);
    throw error;
  }
}
```

### 自動追跡（推奨）

```typescript
import { withAgentTracking } from '../scripts/dashboard-events.js';

async function executeAgent(issueNumber: number) {
  return await withAgentTracking('coordinator', issueNumber, async (progress) => {
    progress(10, 'Starting analysis...');

    // Step 1: Analyze
    const analysis = await analyzeIssue(issueNumber);
    progress(30, 'Analysis complete');

    // Step 2: Create tasks
    const tasks = await createTasks(analysis);
    progress(60, 'Tasks created');

    // Step 3: Assign agents
    await assignAgents(tasks);
    progress(100, 'Completed!');

    return { success: true, tasks };
  });
}
```

---

## 実際の統合例

### 例1: IssueAgent (`scripts/ai-label-issue.ts`)

```typescript
import { withAgentTracking } from './dashboard-events.js';

async function main() {
  const issueNumber = parseInt(process.argv[2], 10);

  await withAgentTracking('issue', issueNumber, async (progress) => {
    progress(10, 'Fetching issue data...');
    const issue = await fetchIssue(issueNumber);

    progress(30, 'Analyzing with Claude AI...');
    const suggestion = await analyzeIssueWithAI(issue);

    progress(60, 'Applying labels...');
    await applyLabels(issueNumber, suggestion.labels);

    progress(80, 'Adding analysis comment...');
    await addComment(issueNumber, suggestion.reasoning);

    progress(100, 'Completed!');
    return { success: true, labelsApplied: suggestion.labels };
  });
}
```

**ダッシュボードでの表示:**
```
Issue #47 → 🤖 IssueAgent (Running - 60%)
             "Applying labels..."
```

---

### 例2: CoordinatorAgent

```typescript
import { withAgentTracking } from './dashboard-events.js';

async function coordinateTask(issueNumber: number) {
  await withAgentTracking('coordinator', issueNumber, async (progress) => {
    progress(10, 'Analyzing dependencies...');
    const deps = await analyzeDependencies(issueNumber);

    progress(30, 'Building DAG...');
    const dag = await buildDAG(deps);

    progress(50, 'Assigning specialist agents...');
    const assignments = await assignSpecialists(dag);

    progress(80, 'Creating sub-tasks...');
    await createSubTasks(assignments);

    progress(100, 'Coordination complete!');
    return { success: true, subTasks: assignments.length };
  });
}
```

---

## 環境変数

### `DASHBOARD_URL`

ダッシュボードサーバーのURL（デフォルト: `http://localhost:3001`）

```bash
export DASHBOARD_URL=https://dashboard.souga.dev
```

### `DEBUG`

デバッグログを有効化

```bash
export DEBUG=1
npm run ai:label norik3333 Souga 47
```

出力:
```
📡 Agent event sent: started - issue on #47
📡 Agent event sent: progress - issue on #47
📡 Agent event sent: completed - issue on #47
```

---

## トラブルシューティング

### イベントが送信されない

**原因1: ダッシュボードサーバーが起動していない**
```bash
# サーバーを起動
pnpm dashboard:server
```

**原因2: Hookスクリプトに実行権限がない**
```bash
chmod +x .claude/hooks/agent-event.sh
```

**原因3: `curl`コマンドがない**
```bash
# macOS/Linux: 通常はインストール済み
which curl

# Windows: WSLまたはGit Bashを使用
```

### ダッシュボードにイベントが表示されない

**デバッグモードで確認:**
```bash
DEBUG=1 npm run ai:label norik3333 Souga 47
```

**サーバーログを確認:**
```bash
# バックエンドのログ
tail -f packages/dashboard-server/logs/*.log

# または直接確認
pnpm dashboard:server
# → "📡 Agent event: started - issue on #47" と表示されるはず
```

**手動でテスト:**
```bash
# Hook直接実行
./.claude/hooks/agent-event.sh started coordinator 47

# curlで直接送信
curl -X POST http://localhost:3001/api/agent-event \
  -H "Content-Type: application/json" \
  -d '{"eventType":"started","agentId":"coordinator","issueNumber":47}'
```

---

## 今後の拡張

### 計画中の機能

- [ ] Agent間の依存関係追跡
- [ ] エラーの自動リトライ
- [ ] Slack/Discord通知連携
- [ ] メトリクス収集（実行時間、成功率）
- [ ] Agent実行履歴の永続化

### カスタムHooks

独自のHookを追加できます：

```bash
# .claude/hooks/custom-event.sh
#!/bin/bash
# Custom event processing
curl -X POST http://localhost:3001/api/custom-event \
  -H "Content-Type: application/json" \
  -d '{"type":"custom","data":"..."}'
```

---

## 関連ドキュメント

- [Agent Visualization Dashboard](../../docs/AGENT_VISUALIZATION_DASHBOARD.md)
- [Dashboard Server README](../../packages/dashboard-server/README.md)
- [Dependency Visualization](../../docs/DEPENDENCY_VISUALIZATION.md)
- [WebHook Setup](../../packages/dashboard-server/WEBHOOK_SETUP.md)
