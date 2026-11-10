---
source_sha256: 51b9f47e2da48591f4fbb303664be100c77e55dc0061d53ca57b0818fe1c82e6
category: writing
tier: core
incidents:
  - "Non-English test method names broke display in tools, CI reports, and terminals; corrected twice in the same day"
last_reviewed: 2026-11-10
---

# Test naming

## Method names are always English; put the native language in the docblock

```php
/** 服務類型不支援批次 API 時，回 422 並提示改用單筆操作 */
public function test_batch_fetch_returns_422_when_type_does_not_support_batch(): void
```

- Method names describe behavior: `test_<action>_<result>_when_<condition>`.
- Chinese (or another native language) goes only in the docblock or comments, describing the scenario and expectation.
- Existing non-English method names are legacy; don't rename them in passing when editing existing tests (that's out of scope). But tests you add must use English.

**Why:** Corrected twice in the same day. Non-English method names display incorrectly in some tools, CI reports, and terminals, and they also lead new tests to copy the old style.

## Test structure <!-- 慣例 -->

Write in three parts, Arrange, Act, Assert, with a blank line between each. One test verifies one behavior.
