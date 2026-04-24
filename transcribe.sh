#!/bin/bash
# Frame.io 動画文字起こしツール (Groq API版)
# 使い方: ./transcribe.sh <Frame.io URL>
# 対応URL:
#   - 共有リンク:   https://f.io/xxxxx
#   - レビューURL:  https://app.frame.io/reviews/xxxxx
#   - アセットID:   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"
FRAMEIO_TOKEN="${FRAMEIO_TOKEN:-__FRAMEIO_TOKEN__}"
GROQ_API_KEY="${GROQ_API_KEY:-__GROQ_API_KEY__}"
TMPDIR_BASE="/tmp/frameio-transcribe"
mkdir -p "$TMPDIR_BASE"

# ---------- 引数チェック ----------
INPUT="${1:-}"
[ -z "$INPUT" ] && { echo "❌ 使い方: $0 <Frame.io URL>" >&2; exit 1; }

info() { echo "📌 $1"; }

# ---------- 動画URL取得 ----------
get_video_url() {
    local url="$1"

    # 1. APIトークンでアセットID直接取得
    if [[ "$url" =~ ^[a-f0-9-]{36}$ ]]; then
        local asset_json
        asset_json=$(curl -sf "https://api.frame.io/v2/assets/$url" \
            -H "Authorization: Bearer $FRAMEIO_TOKEN" 2>/dev/null) || true
        if [ -n "$asset_json" ]; then
            local dl_url
            dl_url=$(echo "$asset_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('original','') or d.get('h264_1080_best','') or d.get('h264_720',''))" 2>/dev/null)
            [ -n "$dl_url" ] && { echo "$dl_url"; return 0; }
        fi
    fi

    # 2. レビューリンク経由
    if [[ "$url" =~ reviews/([a-f0-9-]+) ]]; then
        local review_id="${BASH_REMATCH[1]}"
        local items_json
        items_json=$(curl -sf "https://api.frame.io/v2/review_links/$review_id/items" \
            -H "Authorization: Bearer $FRAMEIO_TOKEN" 2>/dev/null) || true
        if [ -n "$items_json" ]; then
            local asset_id
            asset_id=$(echo "$items_json" | python3 -c "
import json,sys
for item in json.load(sys.stdin):
    a=item.get('asset',item)
    if a.get('type')=='file': print(a['id']); break
" 2>/dev/null)
            [ -n "$asset_id" ] && { get_video_url "$asset_id"; return $?; }
        fi
    fi

    # 3. Playwright でブラウザ経由（共有リンク・f.io短縮URL用）
    echo "📌 ブラウザ経由で動画URLを取得中..." >&2
    (cd "$SCRIPT_DIR" && node grab-video-url.mjs "$url" 2>/dev/null)
}

# ---------- メイン処理 ----------
info "動画URLを取得中..."
VIDEO_URL=$(get_video_url "$INPUT") || { echo "❌ 動画URLの取得に失敗" >&2; exit 1; }
info "動画URL取得成功"

# 音声抽出（MP3 32kbps = 小さいファイルでAPI送信が速い）
AUDIO_TMP="$TMPDIR_BASE/audio_$$.mp3"
cleanup() { rm -f "$AUDIO_TMP"; }
trap cleanup EXIT

info "音声を抽出中..."
ffmpeg -y -i "$VIDEO_URL" -vn -acodec libmp3lame -ar 16000 -ac 1 -b:a 32k "$AUDIO_TMP" \
    -loglevel error 2>/dev/null || true

[ ! -s "$AUDIO_TMP" ] && { echo "❌ 音声抽出に失敗" >&2; exit 1; }

FILESIZE=$(ls -lh "$AUDIO_TMP" | awk '{print $5}')
DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$AUDIO_TMP" 2>/dev/null | cut -d. -f1)
info "音声長: ${DURATION}秒（$(( DURATION / 60 ))分$(( DURATION % 60 ))秒）/ ファイルサイズ: ${FILESIZE}"

# Groq APIで文字起こし
info "Groq API (whisper-large-v3) で文字起こし中..."
START=$(date +%s)

curl -s https://api.groq.com/openai/v1/audio/transcriptions \
    -H "Authorization: Bearer $GROQ_API_KEY" \
    -F file=@"$AUDIO_TMP" \
    -F model="whisper-large-v3" \
    -F language="ja" \
    -F response_format="text" \
    -o "$TMPDIR_BASE/result_$$.txt"

END=$(date +%s)
ELAPSED=$((END - START))

if [ ! -s "$TMPDIR_BASE/result_$$.txt" ]; then
    echo "❌ 文字起こし結果が空です" >&2; exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 文字起こし完了（${ELAPSED}秒 / whisper-large-v3）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$TMPDIR_BASE/result_$$.txt"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

rm -f "$TMPDIR_BASE/result_$$.txt"
