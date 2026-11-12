// 下載端點：直接回傳匯出檔，沒有密碼保護
import { readFileSync } from 'node:fs';

export function handleDownload(req, res) {
  res.setHeader('Content-Type', 'text/csv');
  res.end(readFileSync(req.query.path));
}
