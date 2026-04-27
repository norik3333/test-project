---
description: 双雅システムを最新版に更新する（git pull → ビルド → グローバル再インストール）
---

# 双雅 Update

双雅のソースリポジトリを最新に更新し、ビルド → グローバル再インストールを自動実行する。

## Usage

```bash
/souga-update
```

## Execution Steps

### Step 1: 現在のバージョン確認

```bash
souga --version 2>/dev/null || echo "NOT_INSTALLED"
```

### Step 2: SOUGA_REPO を特定

以下の順に探す:

```bash
SOUGA_REPO=""
for candidate in \
  "/Volumes/外SSD/project/souga system/souga_system" \
  "$HOME/project/souga_system" \
  "$HOME/souga_system"; do
  if [ -f "$candidate/packages/cli/package.json" ]; then
    SOUGA_REPO="$candidate"
    break
  fi
done

if [ -z "$SOUGA_REPO" ]; then
  echo "ERROR: souga_system リポジトリが見つかりません"
  echo "git clone https://github.com/norik3333/souga_system.git でクローンしてください"
  exit 1
fi
echo "SOUGA_REPO: $SOUGA_REPO"
```

### Step 3: git pull

```bash
cd "$SOUGA_REPO"
git fetch origin
git pull origin main
```

### Step 4: ビルド

```bash
cd "$SOUGA_REPO"
npm run build
```

### Step 5: グローバル再インストール

```bash
npm install -g "$SOUGA_REPO/packages/cli"
```

### Step 6: .claude/ ファイル更新

```bash
souga update .
```

### Step 7: バージョン確認

```bash
souga --version
```

### Step 8: 結果報告

```
SOUGA UPDATE COMPLETE
=====================
Before: x.x.x
After:  x.x.x
Method: git-pull + source-build
Global: ✅
=====================
```
