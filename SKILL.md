---
name: frameio-thumbnail-copy
description: Frame.ioリンクを貼るだけで文字起こし→サムネコピー案を自動生成する
user_invocable: true
---

# Frame.io → サムネコピー自動生成スキル

Frame.ioの共有リンクから動画を文字起こしし、CTRの高いサムネイルコピー案を自動生成する。

## トリガー

ユーザーが `/frameio-thumbnail-copy` と入力した時、またはFrame.ioリンクからサムネコピーを求められた時に起動する。

## 入力

- Frame.io共有リンク（例: `https://f.io/xxxxx`）
- 引数として渡される（例: `/frameio-thumbnail-copy https://f.io/xxxxx`）

## 処理フロー

### Step 1: 文字起こし

以下のコマンドを実行して文字起こしを取得する:

```bash
# 1. Frame.ioからHLS動画URLを取得
VIDEO_URL=$(cd ~/frameio-tools && node grab-video-url.mjs "<Frame.io URL>" 2>/dev/null)

# 2. 音声抽出（MP3 32kbps）
ffmpeg -y -i "$VIDEO_URL" -vn -acodec libmp3lame -ar 16000 -ac 1 -b:a 32k /tmp/frameio-transcribe/audio_skill.mp3 -loglevel error 2>/dev/null || true

# 3. Groq APIで文字起こし
curl -s https://api.groq.com/openai/v1/audio/transcriptions \
  -H "Authorization: Bearer $GROQ_API_KEY" \
  -F file=@/tmp/frameio-transcribe/audio_skill.mp3 \
  -F model="whisper-large-v3" \
  -F language="ja" \
  -F response_format="text"
```

処理が完了したら、文字起こし結果を読み込む。

### Step 2: 動画内容の分析

文字起こしテキストから以下を抽出する:

1. **動画のテーマ・ジャンル**（何についての動画か）
2. **ターゲット視聴者**（誰に向けた動画か）
3. **最もインパクトのある数字・事実**（収入、期間、結果など）
4. **感情が動くポイント**（驚き、共感、憧れ、恐怖）
5. **キーワード・固有名詞**（人名、サービス名、専門用語）

### Step 3: サムネコピー生成

以下の5型で各3〜5案ずつ生成する:

#### サムネコピー5型ルール

1. **数字ギャップ型** — 具体数値でBefore/Afterの落差を見せる（例: 年収300万→月商350万）
2. **煽り・挑発型** — ターゲットの痛みを突く（例: まだ独学で消耗してるの）
3. **好奇心・潜入型** — 「見たい」「知りたい」を刺激（例: 全員に月収聞いてみた）
4. **共感・あるある型** — ターゲットの日常に刺さる（例: 家だと絶対サボるやつへ）
5. **ぶっ飛び型** — 予想外の展開で目を引く（例: 彼女と別れて居候して稼いだ）

#### 文字数ルール
- **全角13文字以内を目指す**（スマホサムネで読める限界）
- 最大でも15文字以内
- 「てにをは」を削る、体言止めにする、主語を消す

### Step 4: 出力フォーマット

以下の形式で出力する:

```
## 動画分析
- テーマ: ○○
- ターゲット: ○○
- 最強フック: ○○

## サムネコピー案

### 数字ギャップ型
1. ○○（○文字）
2. ○○（○文字）
3. ○○（○文字）

### 煽り・挑発型
...（同様）

### 好奇心・潜入型
...

### 共感・あるある型
...

### ぶっ飛び型
...

## TOP3推し
1. ○○ — 理由
2. ○○ — 理由
3. ○○ — 理由
```

## 注意事項

- 文字起こしの一時ファイルは処理後に削除する
- Groq APIキーはスクリプト内にハードコード済み
- Frame.ioの共有リンク（f.io短縮URL）に対応
- 音声抽出時のNALエラーは無視してよい（ビデオトラック関連で音声に影響なし）
