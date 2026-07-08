const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

// Firebase Secret Manager に登録する2つの秘密情報
// 1. APP_PASSWORD    : アプリ利用者全員で共有する合言葉
// 2. ANTHROPIC_API_KEY: Claude APIキー(画像認識に使用)
const APP_PASSWORD = defineSecret("APP_PASSWORD");
const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

const RECOGNITION_PROMPT = `あなたは麻雀の牌画像を認識するアシスタントです。
添付された麻雀の手牌の写真を見て、写っている牌をすべて識別してください。

出力は必ず次のJSON形式のみで返してください。説明文やコードブロックの記号(\`\`\`)は一切含めないでください。

{
  "tiles": ["1m", "2m", "3m", "4p", "5p", "0p", "7s", "8s", "9s", "1z", "1z", "5z", "5z", "5z"],
  "confidence": "high" | "medium" | "low",
  "notes": "認識が難しかった点があれば日本語で簡潔に記載。無ければ空文字"
}

表記ルール:
- 萬子は m、筒子は p、索子は s、字牌は z を末尾に付ける (例: 3m, 7p, 2s)
- 字牌の数字: 1=東 2=南 3=西 4=北 5=白 6=發 7=中
- 赤ドラ(赤5)は通常の5ではなく "0" で表記する (例: 赤5萬なら "0m")
- 手牌に写っている枚数分だけ配列に入れる(通常13枚または和了後14枚)
- 牌の並び順は問わない
`;

exports.recognizeTiles = onRequest(
  { secrets: [APP_PASSWORD, ANTHROPIC_API_KEY], cors: true, region: "asia-northeast1" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "POST only" });
      return;
    }

    // --- 共通パスワードによる認証チェック ---
    const providedPassword = req.get("X-App-Password") || "";
    if (providedPassword !== APP_PASSWORD.value()) {
      logger.warn("Unauthorized request: invalid password");
      res.status(401).json({ error: "パスワードが違います" });
      return;
    }

    const { imageBase64, mediaType } = req.body || {};
    if (!imageBase64 || !mediaType) {
      res.status(400).json({ error: "imageBase64 と mediaType は必須です" });
      return;
    }
    if (!["image/jpeg", "image/png", "image/webp"].includes(mediaType)) {
      res.status(400).json({ error: "対応していない画像形式です" });
      return;
    }

    try {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": ANTHROPIC_API_KEY.value(),
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-sonnet-4-6",
          max_tokens: 1024,
          messages: [
            {
              role: "user",
              content: [
                {
                  type: "image",
                  source: { type: "base64", media_type: mediaType, data: imageBase64 },
                },
                { type: "text", text: RECOGNITION_PROMPT },
              ],
            },
          ],
        }),
      });

      if (!response.ok) {
        const errText = await response.text();
        logger.error("Anthropic API error", errText);
        res.status(502).json({ error: "画像認識APIの呼び出しに失敗しました" });
        return;
      }

      const data = await response.json();
      const textBlock = (data.content || []).find((b) => b.type === "text");
      if (!textBlock) {
        res.status(502).json({ error: "認識結果を取得できませんでした" });
        return;
      }

      let parsed;
      try {
        const cleaned = textBlock.text.replace(/```json|```/g, "").trim();
        parsed = JSON.parse(cleaned);
      } catch (e) {
        logger.error("JSON parse error", textBlock.text);
        res.status(502).json({ error: "認識結果の解析に失敗しました", raw: textBlock.text });
        return;
      }

      res.status(200).json(parsed);
    } catch (err) {
      logger.error("Unexpected error", err);
      res.status(500).json({ error: "サーバーエラーが発生しました" });
    }
  }
);
