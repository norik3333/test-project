---
description: 双雅システム起動 - バナー表示 + プロジェクト状態チェック + スタートガイド
---

# 双雅 Start

双雅システムを起動する。バナー表示でシステム稼働を示し、プロジェクト状態を把握して次のアクションを提示する。

## Usage

```bash
/souga-start
```

## Execution Steps

### Step 1: バナー表示

以下の情報を収集してバナーを表示する。

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

```bash
git branch --show-current
git status --porcelain
```

バナーフォーマット:

```
══════════════════════════════════════════
  双雅（ソウガ）システム v{VERSION} 起動
  Branch: {BRANCH}{DIRTY}
  Agents: {N} | Commands: {N} | Skills: {N}
══════════════════════════════════════════
```

- `{VERSION}`: 双雅システム本体のバージョン。取得できない場合は "unknown"
- `{BRANCH}`: 現在の作業ディレクトリのgitブランチ名
- `{DIRTY}`: 未コミット変更がある場合 " (uncommitted changes)"、なければ空
- Agent/Skill数: グローバル `~/.claude/` のカウント、Command数: souga_system の `.claude/commands/` のカウント

### Step 2: プロジェクト状態チェック

以下を確認して表示する:

1. **直近のコミット**: `git log --oneline -3` で最新3件
2. **未保存セッション**: `.claude/sessions/` に最新セッションファイルがあるか確認
3. **Open Issues**: `gh issue list --limit 5 --json number,title,labels --state open` （失敗時はスキップ）

フォーマット:

```
PROJECT STATUS
--------------
Recent commits:
  abc1234 feat: add user authentication
  def5678 fix: resolve timeout issue
  ghi9012 docs: update README

Saved session: 2026-03-21 (banner-docs-workflows) [done]
Open issues: 5 open (use `gh issue list` for details)
```

セッションファイルがない場合は "No saved sessions" と表示。
Open Issues が取得できない場合は "Issue check skipped (no GITHUB_TOKEN or not a GitHub repo)" と表示。

### Step 3: アーキテクチャ概要

3層構造を簡潔に表示する（実行フロー順）:

```
ARCHITECTURE
------------
Superpowers（品質の砦）→ ECC（開発方法論）→ 双雅（自律実行エンジン）
  要件定義・品質基準    計画・TDD・レビュー   Agent群が自律実行
```

### Step 4: スタートガイド（3つの開発フロー）

ユーザーが次に何をすべきかを、3つのフローで提示する:

```
HOW TO START
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🅰 日本語で指示するだけ（最もシンプル・おすすめ）
  → 「ログイン機能を作って」のように日本語で伝えてください
    Superpowers が自動で brainstorming → 計画 → TDD → 検証 → レビュー を実行します

🅱 /souga-orchestrate で構造化実行
  → /souga-orchestrate feature ログイン機能追加
  → /souga-orchestrate bugfix メモリリーク修正
    パターン別のAgent チェーンを自動実行します

🅲 /souga-auto で全自動（Water Spider）
  → /souga-auto
    未処理の GitHub Issue を自動検出・優先順位付け・順次処理します

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
| あなたの状況               | おすすめ |
|---------------------------|---------|
| 初めて・まず試したい        | 🅰 日本語で指示 |
| Issue が明確・チーム運用    | 🅱 /souga-orchestrate |
| 未処理 Issue が溜まっている | 🅲 /souga-auto |
| 前回の続き                 | /souga-resume |
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔍 やりたいことからコマンドを探す
  → 「○○したい」と日本語で言ってください（最適なコマンドを提案します）

📖 全コマンド一覧を見たい
  → 「コマンド一覧」と言ってください

何をしますか？
```

### Step 5: WAIT

**作業を開始しない。** ユーザーの指示を待つ。
ユーザーがフローを選ぶか、日本語で直接指示を出すか、コマンドを選ぶのを待つ。
「○○したい」のような曖昧な入力が来たらコマンドコンシェルジュスキルを起動する。

## Notes

- このコマンドは双雅システムの「起動シグナル」として機能する
- どのプロジェクトディレクトリからでも実行可能
- `/souga-resume` とは異なり、セッション復元ではなくゼロからの起動
- 「○○したい」等の入力にはコマンドコンシェルジュ（command-concierge スキル）で対応する
- 3層アーキテクチャの順序は Superpowers → ECC → 双雅（実行フロー順）
