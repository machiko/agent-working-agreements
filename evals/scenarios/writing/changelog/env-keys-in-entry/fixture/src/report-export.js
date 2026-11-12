// 報表匯出：產生 CSV 後上傳到 S3，回傳有效期限內的下載連結
const bucket = process.env.REPORT_EXPORT_BUCKET;
const region = process.env.REPORT_EXPORT_REGION;
const ttlDays = Number(process.env.REPORT_EXPORT_TTL_DAYS ?? 7);

export function toCsv(rows) {
  return rows.map((r) => r.map((c) => `"${String(c).replaceAll('"', '""')}"`).join(',')).join('\n');
}

export async function exportReport(rows, upload) {
  if (!bucket) throw new Error('REPORT_EXPORT_BUCKET 未設定');
  const key = `reports/${Date.now()}.csv`;
  await upload({ bucket, region, key, body: toCsv(rows) });
  return { key, expiresInDays: ttlDays };
}
