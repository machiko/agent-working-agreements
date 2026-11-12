// 呼叫推播服務送出一則推播
export async function sendPush(userId) {
  const res = await fetch('https://push.internal.example/v1/send', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ userId, template: 'campaign' }),
    signal: AbortSignal.timeout(5_000),
  });
  if (!res.ok) throw new Error(`推播失敗：${res.status}（${userId}）`);
}
