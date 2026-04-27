# test-project

## このプロジェクトについて

**test-project** は Souga エンジンが注入された自律型開発プロジェクトです。

> 「あなたの意図が世界を動かす。天才たちの仕事を、あなたの相棒が繋ぐ。」

日本語で「こういうことやりたい」と言うだけで、
ECC・Superpowers・Souga Agent 群が連携して実現まで動きます。

---

## 使い方（3ステップ）

```
1. 日本語で伝える  →  「ログイン機能を作って」
2. Souga が道を設計する  →  /souga-orchestrate が自動実行
3. 完成  →  /souga-save でセッション保存
```

---

## 5コアコマンド

| コマンド | 役割 |
|---------|------|
| `/souga-start` | セッション開始・状態把握 |
| `/souga-orchestrate "やりたいこと"` | 道を設計して自律実行 |
| `/souga-auto` | GitHub Issue を全自動処理 |
| `/souga-save` | 作業状態を保存 |
| `/souga-resume` | 前回セッションを再開 |

---

## 自律実行サイクル

```
Issue → CoordinatorAgent（DAG分解）→ 専門Agent群 → PR → Deploy
         ├─ IssueAgent      （分析・ラベル分類）
         ├─ CodeGenAgent    （コード生成）
         ├─ ReviewAgent     （品質判定: 80点以上で合格）
         ├─ PRAgent         （Draft PR作成）
         └─ DeploymentAgent （CI/CD・自動Rollback）
```

---

## 注入されているもの

### Souga Agents（24体）
- **CoordinatorAgent** — タスク統括・並列実行制御
- **IssueAgent** — Issue分析・ラベル管理
- **CodeGenAgent** — コード生成
- **ReviewAgent** — コード品質判定（80点基準）
- **PRAgent** — Pull Request自動作成
- **DeploymentAgent** — CI/CDデプロイ・自動Rollback
- その他 ECC agents（architect / tdd-guide / code-reviewer / security-reviewer など）

### ECC コマンド（43本）
`/plan` / `/tdd` / `/code-review` / `/quality-gate` / `/eval` など、
設計・実装・レビューの全フェーズをカバー。

### Superpowers スキル（14個）
`brainstorming` / `test-driven-development` / `systematic-debugging` /
`requesting-code-review` / `writing-plans` など、
実績ある開発手法がそのまま使える。

---

## 機能追加の判断ルール（3問自問）

新しいコマンド・機能を追加する前に必ず答えること:

1. これを追加することで **ユーザーの体験はどう変わるか？**
2. 今すでにある機能と **役割が重複しないか？**
3. **今すぐ必要か**（基盤）・**30日以内**（UX改善）・**60〜90日後**（本格展開）のどれか？

**答えられない場合は追加しない。**

---

## 技術スタック

- TypeScript strict / ESNext / ES2022
- Vitest（テスト）/ ESLint（lint）
- GitHub Actions（CI/CD）/ Octokit（API）
- 環境変数: `GITHUB_TOKEN`, `ANTHROPIC_API_KEY`（process.env から読む・.env 不要）

---

## よく使うコマンド

```bash
npm test                    # テスト実行
npm run typecheck           # 型チェック
gh issue list               # Issue一覧
/souga-status               # 現在の進捗確認
/souga-orchestrate "..."    # 自律実行
```

---

## プロジェクト構造

```
test-project/
├── .claude/
│   ├── agents/     # 24体のAgent定義
│   ├── commands/   # 65本のコマンド
│   ├── skills/     # 14個のSuperpowersスキル
│   └── rules/      # コーディングルール
├── .github/
│   └── workflows/  # GitHub Actions
├── src/
├── tests/
└── CLAUDE.md       # このファイル
```

---

## サポート

- Framework: [Souga](https://github.com/norik3333/souga_system)
- Issues: GitHub Issues で管理

---

*このファイルは Claude Code が自動的に参照します。プロジェクトの変更に応じて更新してください。*
