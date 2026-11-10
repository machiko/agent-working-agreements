## 摘要

<!-- 改了什麼、為什麼。關聯的 issue 寫在最後：Refs #123 -->

## 變更類型

- [ ] 新守則或新條目
- [ ] 修改既有守則內容
- [ ] 腳本、安裝器或 CI
- [ ] 文件

## 新守則或修改守則（其他類型可刪掉這段）

完整標準見 [守則品質標準](https://github.com/machiko/agent-working-agreements/blob/main/docs/rule-quality.md)，流程見 [CONTRIBUTING.md](https://github.com/machiko/agent-working-agreements/blob/main/CONTRIBUTING.md)。

- **事故來源**：<!-- issue 編號或一句話的去識別化描述；沒有事故依據的條目，標題要標「慣例」或「參考」註解 -->
- [ ] frontmatter 的 `incidents` 與 `last_reviewed` 已更新
- [ ] 英文版 `i18n/en/rules/<id>.md` 已逐行同步，並執行 `scripts/check-i18n.sh --stamp en <id>`（不熟英文請在這裡註明，維護者會協助）
- [ ] 評測情境：`evals/scenarios/<category>/<rule>/<情境>/`，`bash tests/eval.test.sh` 通過（只改字句、不改行為的修改可免，請註明）
- [ ] 已去識別化：沒有專案名、公司、人名、私有 IP、內部網域或憑證

## 檢查結果

<!-- 貼上輸出的最後一行，或勾選 -->

- [ ] `scripts/check-budget.sh`
- [ ] `scripts/lint-rules.sh`
- [ ] `scripts/check-schema.sh`
- [ ] `scripts/check-i18n.sh`
- [ ] `scripts/sanitize-check.sh`
- [ ] 相關的 `bash tests/*.test.sh`
