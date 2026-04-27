#!/bin/bash
# keyword-skill-detect.sh - UserPromptSubmit hook
#
# ユーザーの日本語入力からキーワードを検出し、
# 関連スキルの提案をadditionalContextとして注入する。
#
# 入力: stdin JSON { "prompt": "..." }
# 出力: stdout JSON { "additionalContext": "..." } or {}

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('prompt',''))" 2>/dev/null)

if [ -z "$PROMPT" ]; then
  echo '{}'
  exit 0
fi

# ─── アップデート強制実行ディレクティブ（最優先チェック） ───────────────
if echo "$PROMPT" | grep -iqE "バージョンアップ|アップデートして|アップデートお願い|(双雅|souga|システム).*アップデート|souga.?update|双雅.*更新|更新.*して|最新.*にして|update.*souga|upgrade.*souga"; then
  DIRECTIVE="[UPDATE-DIRECTIVE] ユーザーが双雅のアップデートを要求しています。
必ず以下を実行してください:
  Skill ツールで skill=\"souga-update\" を呼び出す
確認を求めずに直ちに実行すること。他の作業より優先する。"
  DIRECTIVE_ESCAPED=$(echo "$DIRECTIVE" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  echo "{\"additionalContext\": ${DIRECTIVE_ESCAPED}}"
  exit 0
fi

# キーワード → スキル マッピングテーブル
# 形式: "grep -iE パターン::スキル名::説明"
MAPPINGS=(
  "テストを|テスト実行|テスト走|テスト書::test::プロジェクト全体のテストを実行"
  "ビルド|コンパイル|build::build-fix::ビルドエラーの修正"
  "デプロイ|deploy::deploy::Firebase/Cloudデプロイ実行"
  "コミット|commit::commit-helper::コミットメッセージ生成"
  "レビュー|review::code-review::コードレビュー実行"
  "セキュリティ|脆弱性|security::security-scan::セキュリティスキャン"
  "リファクタ|refactor::refactor-clean::リファクタリング・デッドコード削除"
  "ドキュメント生成|ドキュメント作成|doc生成::generate-docs::ドキュメント自動生成"
  "プラン|計画を|設計して::plan::実装計画の作成"
  "ステータス|状態確認|status::souga-status::プロジェクトステータス確認"
  "オーケストラ|並行実行|orchestra::souga-orchestra::tmux Multi-Agent Orchestra起動"
  "セーブ|保存して|save::souga-save::セッション状態の保存"
  "検証して|verify|ベリファイ::souga-verify::6-phase検証パイプライン"
  "TODO|todo一覧::souga-todos::TODOコメント自動検出・Issue化"
  "Issue作成|issue作成::create-issue::Agent実行用Issue作成"
  "スキル作成|skill作成|新しいスキル::skill-creator::新しいスキルの作成"
  "クリーンアップ|cleanup|整理して::souga-cleanup::コード整理（De-Sloppify）"
  "学習して|パターン抽出|learn::souga-learn::セッションからパターン抽出"
  "ニュース|アップデート情報|最新情報::souga-news-scout::Anthropic最新ニュース取得"
  "TDD|テスト駆動::tdd::テスト駆動開発ワークフロー"
  "E2E|エンドツーエンド::e2e::E2Eテスト生成・実行"
  "カバレッジ|coverage::test-coverage::テストカバレッジ確認"
)

# マッチしたスキルを収集
MATCHED_SKILLS=()
MATCHED_DESCS=()
for mapping in "${MAPPINGS[@]}"; do
  pattern="${mapping%%::*}"
  rest="${mapping#*::}"
  skill="${rest%%::*}"
  desc="${rest#*::}"

  if echo "$PROMPT" | grep -iqE "$pattern"; then
    # 重複チェック
    already=0
    for ms in "${MATCHED_SKILLS[@]}"; do
      if [ "$ms" = "$skill" ]; then
        already=1
        break
      fi
    done
    if [ "$already" = "0" ]; then
      MATCHED_SKILLS+=("$skill")
      MATCHED_DESCS+=("$desc")
    fi
  fi
done

# マッチなし → 空レスポンス
if [ ${#MATCHED_SKILLS[@]} -eq 0 ]; then
  echo '{}'
  exit 0
fi

# 最大3件に制限
MAX=3
COUNT=${#MATCHED_SKILLS[@]}
if [ "$COUNT" -gt "$MAX" ]; then
  COUNT=$MAX
fi

# 提案メッセージを構築
SUGGESTIONS=""
for ((i=0; i<COUNT; i++)); do
  SUGGESTIONS="${SUGGESTIONS}\n  /${MATCHED_SKILLS[$i]} — ${MATCHED_DESCS[$i]}"
done

# additionalContext として注入
CONTEXT="[keyword-detect] 入力に関連するスキルが見つかりました:${SUGGESTIONS}\n\nスキルを使う場合は Skill ツールで実行してください。ユーザーに提案として伝えてください。"

# JSON出力（改行をエスケープ）
CONTEXT_ESCAPED=$(echo -e "$CONTEXT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
echo "{\"additionalContext\": ${CONTEXT_ESCAPED}}"
