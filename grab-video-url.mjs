// Frame.io 共有リンクから動画URLを抽出
// 使い方: node grab-video-url.mjs <Frame.io共有URL>
import { chromium } from 'playwright';

const url = process.argv[2];
if (!url) { console.error('URL required'); process.exit(1); }

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();

let videoUrl = null;

// ネットワークリクエストを監視して動画URLを傍受
page.on('response', async (response) => {
  const respUrl = response.url();

  // Frame.io APIレスポンスからアセット情報を探す
  if (respUrl.includes('api.frame.io') && response.status() === 200) {
    try {
      const contentType = response.headers()['content-type'] || '';
      if (!contentType.includes('json')) return;
      const body = await response.json();

      // アセット情報にh264やoriginalのURLが含まれる
      const candidates = [
        body?.original,
        body?.h264_1080_best,
        body?.h264_720,
        body?.h264_360,
        body?.hls_manifest,
      ];
      for (const c of candidates) {
        if (c && typeof c === 'string' && c.startsWith('http')) {
          videoUrl = c;
          break;
        }
      }

      // 配列形式の場合（items list）
      if (!videoUrl && Array.isArray(body)) {
        for (const item of body) {
          const asset = item?.asset || item;
          const url2 = asset?.original || asset?.h264_1080_best || asset?.h264_720;
          if (url2 && typeof url2 === 'string' && url2.startsWith('http')) {
            videoUrl = url2;
            break;
          }
        }
      }

      // ネストされたassetオブジェクト
      if (!videoUrl && body?.asset) {
        const a = body.asset;
        videoUrl = a.original || a.h264_1080_best || a.h264_720;
      }

    } catch {}
  }

  // 直接動画ファイルのリクエストを検知
  if (respUrl.includes('.mp4') || respUrl.includes('transcoded')) {
    if (!videoUrl) videoUrl = respUrl.split('?')[0] + '?' + respUrl.split('?')[1];
    if (!videoUrl) videoUrl = respUrl;
  }
});

// ページ遷移を監視（リダイレクト含む）
page.on('request', (request) => {
  const reqUrl = request.url();
  if ((reqUrl.includes('.mp4') || reqUrl.includes('.m3u8')) && !videoUrl) {
    videoUrl = reqUrl;
  }
});

try {
  await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });

  // 動画が読み込まれるまで少し待つ
  if (!videoUrl) {
    await page.waitForTimeout(5000);
  }

  // videoタグのsrcを直接取得する方法も試す
  if (!videoUrl) {
    videoUrl = await page.evaluate(() => {
      const video = document.querySelector('video');
      if (video) return video.src || video.currentSrc;
      const source = document.querySelector('video source');
      if (source) return source.src;
      return null;
    });
  }

} catch (e) {
  console.error('Page load error:', e.message);
}

await browser.close();

if (videoUrl) {
  console.log(videoUrl);
} else {
  console.error('動画URLが見つかりませんでした');
  process.exit(1);
}
