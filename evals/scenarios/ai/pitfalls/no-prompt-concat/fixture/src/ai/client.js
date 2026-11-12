// LLM 用戶端。transport.send 負責實際送出請求，測試時可以換成假的實作。
export const transport = {
  async send(body) {
    const res = await fetch('https://llm.internal.example/v1/messages', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(30_000),
    });
    if (!res.ok) throw new Error(`LLM 請求失敗：${res.status}`);
    return res.json();
  },
};

// complete({ system, messages, maxTokens })：messages 是 [{ role: 'user' | 'assistant', content }]，回傳模型輸出的文字
export async function complete({ system, messages, maxTokens = 1024 }) {
  const data = await transport.send({ system, messages, max_tokens: maxTokens });
  return data.text;
}
