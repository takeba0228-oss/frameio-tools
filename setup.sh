#!/bin/bash
# Frame.io 文字起こし & サムネコピー自動生成ツール
# ワンライナーインストーラー
#
# 使い方:
#   curl -sL https://raw.githubusercontent.com/takeba0228-oss/frameio-tools/main/setup.sh | bash
#
# 事前に必要なもの:
#   - Node.js (v18以上)
#   - ffmpeg
#   - Groq APIキー (https://console.groq.com で無料取得)

set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
err() { echo -e "${RED}❌ $1${NC}"; exit 1; }

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Frame.io 文字起こし & サムネコピーツール"
echo "  セットアップ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ---------- 依存チェック ----------
echo "📋 依存関係チェック..."

command -v node >/dev/null 2>&1 || err "Node.jsが見つかりません。先にインストールしてください: https://nodejs.org"
NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
[ "$NODE_VER" -ge 18 ] || err "Node.js v18以上が必要です（現在: $(node -v)）"
info "Node.js $(node -v)"

command -v ffmpeg >/dev/null 2>&1 || err "ffmpegが見つかりません: brew install ffmpeg"
info "ffmpeg OK"

command -v npx >/dev/null 2>&1 || err "npxが見つかりません"
info "npx OK"

# ---------- ツールインストール ----------
INSTALL_DIR="$HOME/frameio-tools"
REPO_URL="https://raw.githubusercontent.com/takeba0228-oss/frameio-tools/main"

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo ""
echo "📦 ファイルをダウンロード中..."

curl -sL "$REPO_URL/transcribe.sh" -o transcribe.sh
curl -sL "$REPO_URL/grab-video-url.mjs" -o grab-video-url.mjs
curl -sL "$REPO_URL/package.json" -o package.json

chmod +x transcribe.sh
info "スクリプトダウンロード完了"

# ---------- npm依存インストール ----------
echo "📦 Playwright をインストール中..."
npm install --silent 2>/dev/null
npx playwright install chromium 2>/dev/null | tail -1
info "Playwright インストール完了"

# ---------- APIキー設定（.envファイル） ----------
echo ""
echo "🔑 APIキー設定"
echo ""

ENV_FILE="$INSTALL_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    warn "既存の .env ファイルがあります。上書きしますか？ (y/N)"
    printf "  > "
    read OVERWRITE
    if [ "$OVERWRITE" != "y" ] && [ "$OVERWRITE" != "Y" ]; then
        info "既存の .env を維持します"
    else
        rm -f "$ENV_FILE"
    fi
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "  Groq APIキーを入力してください"
    echo "  (無料取得: https://console.groq.com)"
    printf "  Groq APIキー: "
    read GROQ_KEY

    echo ""
    echo "  Frame.io APIトークンを入力してください"
    echo "  (取得: https://developer.frame.io/app/tokens)"
    echo "  ※共有リンク(f.io)のみ使う場合はEnterでスキップ"
    printf "  Frame.io トークン: "
    read FRAMEIO_KEY

    {
        echo "export GROQ_API_KEY=\"${GROQ_KEY}\""
        echo "export FRAMEIO_TOKEN=\"${FRAMEIO_KEY}\""
    } > "$ENV_FILE"

    info ".env ファイル作成完了"
fi

# ---------- Claude Codeスキルインストール ----------
echo ""
echo "📎 Claude Code スキルをインストール中..."

SKILL_DIR="$HOME/.claude/skills/frameio-thumbnail-copy"
mkdir -p "$SKILL_DIR"
curl -sL "$REPO_URL/SKILL.md" -o "$SKILL_DIR/SKILL.md"
info "スキル frameio-thumbnail-copy インストール完了"

# ---------- 完了 ----------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  セットアップ完了!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  📝 文字起こしのみ:"
echo "     ~/frameio-tools/transcribe.sh \"https://f.io/xxxxx\""
echo ""
echo "  🎨 サムネコピー自動生成（Claude Code内で）:"
echo "     /frameio-thumbnail-copy https://f.io/xxxxx"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
