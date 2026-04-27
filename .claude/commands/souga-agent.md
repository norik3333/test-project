---
description: 双雅 Agent実行 - Issue自動処理
---

# 双雅 Agent実行

GitHub IssueをSouga Autonomous Agentで自動処理します。

## 利用可能なMCPツール

Claude CodeからSouga機能を直接呼び出せます：

### `souga__agent_run`
Autonomous Agentを実行してIssueを自動処理

**パラメータ**:
- `issueNumber`: 処理するIssue番号
- `issueNumbers`: 複数Issue（並列処理）
- `concurrency`: 並行実行数（デフォルト: 2）
- `dryRun`: ドライラン（デフォルト: false）

**使用例**:
```
単一Issue処理:
souga__agent_run({ issueNumber: 123 })

複数Issue並列処理:
souga__agent_run({ issueNumbers: [123, 124, 125], concurrency: 3 })

Dry run:
souga__agent_run({ issueNumber: 123, dryRun: true })
```

### `souga__auto`
Water Spider Agent（全自動モード）起動

**パラメータ**:
- `maxIssues`: 最大処理Issue数（デフォルト: 5）
- `interval`: ポーリング間隔秒（デフォルト: 60）

**使用例**:
```
全自動モード起動:
souga__auto({ maxIssues: 10, interval: 30 })
```

## 実行フロー

```
Issue作成/検出
    ↓
CoordinatorAgent（タスク分解・DAG構築）
    ↓ 並行実行
├─ IssueAgent（分析・Label付与）
├─ CodeGenAgent（Claude Sonnet 4でコード生成）
├─ ReviewAgent（品質チェック≥80点）
└─ TestAgent（テスト実行）
    ↓
PRAgent（Draft PR作成）
    ↓
人間レビュー待ち
```

## コマンドライン実行

MCPツールの代わりにコマンドラインでも実行可能:

```bash
# 単一Issue処理
npx souga agent run --issue 123

# 複数Issue並行処理
npx souga agent run --issues 123,124,125 --concurrency 3

# 全自動モード
npx souga auto --max-issues 10

# Dry run
npx souga agent run --issue 123 --dry-run
```

## 環境変数

`.env` ファイルに以下を設定:

```bash
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
REPOSITORY=owner/repo
DEVICE_IDENTIFIER=MacBook Pro 16-inch
```

## 成功条件

✅ **必須**:
- Issue分析完了
- コード生成成功
- 品質スコア ≥80点
- Draft PR作成

✅ **品質**:
- TypeScriptエラー 0件
- ESLintエラー 0件
- セキュリティスキャン合格
- テストカバレッジ ≥80%

## エスカレーション

以下の場合、自動エスカレーション:

| 条件 | エスカレーション先 | 重要度 |
|------|------------------|--------|
| アーキテクチャ問題 | TechLead | Sev.2-High |
| セキュリティ脆弱性 | CISO | Sev.1-Critical |
| ビジネス優先度 | PO | Sev.3-Medium |
| 循環依存検出 | TechLead | Sev.2-High |

---

💡 **ヒント**: MCPツールを使うと、Claude Codeが自動的にパラメータを推論して実行します。
