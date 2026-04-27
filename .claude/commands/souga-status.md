---
description: Sougaプロジェクトステータス確認
---

# Sougaプロジェクトステータス

プロジェクトのSouga統合状態、GitHub Issues、Actionsの状態を確認します。

## MCPツール

### `souga__get_status`
プロジェクトのSouga/Claude Code統合状態を取得（軽量・高速）

**使用例**:
```
プロジェクト状態確認:
souga__get_status({})
```

**返却情報**:
- 作業ディレクトリ
- Souga統合状態（.souga.yml存在確認）
- Claude Code統合状態（.claude/存在確認）
- パッケージ情報（name, version, 依存関係数）

### `souga__status`
詳細なプロジェクトステータス（GitHub API経由）

**パラメータ**:
- `watch`: ウォッチモード（自動更新）

**使用例**:
```
詳細ステータス:
souga__status({})

ウォッチモード:
souga__status({ watch: true })
```

**返却情報**:
- GitHub Issues状態（Open/Closed/In Progress）
- GitHub Actions実行状態
- Projects V2カンバンボード状態
- 組織設計ラベル分布
- Agent実行履歴

## コマンドライン実行

```bash
# 軽量ステータス
npx souga status

# ウォッチモード（5秒ごと自動更新）
npx souga status --watch
```

## 表示例

```
📊 Sougaプロジェクトステータス

プロジェクト: my-awesome-app
Repository: github.com/user/my-awesome-app
Souga Version: 0.6.0

GitHub Issues:
  📋 Open: 5
  ✅ Closed: 23
  🚧 In Progress: 2

GitHub Actions:
  ✅ Build: Success (2m 34s ago)
  ✅ Test: Success (2m 34s ago)
  🔄 Deploy: Running

Projects V2:
  📊 Backlog: 3
  🚧 In Progress: 2
  👀 Review: 1
  ✅ Done: 20

Agents:
  🤖 CoordinatorAgent: 待機中
  🧠 CodeGenAgent: 待機中
  📊 ReviewAgent: 待機中
  🚀 PRAgent: 待機中

組織設計ラベル:
  🔴 緊急度-高: 2
  🟡 緊急度-中: 3
  🔵 規模-小: 4
  🟣 規模-中: 1
```

---

💡 **ヒント**: `souga__get_status` は軽量で高速。`souga__status` は詳細情報取得（GitHub API使用）。
