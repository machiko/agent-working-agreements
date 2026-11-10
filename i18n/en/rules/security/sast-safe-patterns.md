---
source_sha256: ccedc70575b44a8f08aa0402e69d9b0d2891790833cbffa2e9da2f6df4f36f65
category: security
tier: optional
label: "SAST-safe coding patterns"
summary: "Avoid, at write time, the 8 patterns that Checkmarx-style scanners commonly flag. Pick this only if the project runs SAST scans; load only when editing code"
paths:
  - "**/*.{php,js,mjs,ts,tsx,jsx,vue}"
incidents:
  - "Fix PRs for commercial SAST scanner alerts often needed a second and third round of patching"
last_reviewed: 2026-11-10
---

# Patterns that avoid SAST alerts up front

> Distilled from many fix PRs for commercial SAST scanner (Checkmarx-style) alerts. These scanners mostly judge by "shape", so semantically correct code gets flagged too. One round of after-the-fact fixes usually leaves stray findings behind, requiring a second and third pass. So apply the patterns below when writing new code.
>
> Examples are mostly PHP/Laravel and browser-side JS; the principles apply to other languages.

## 1. Frontend fetch: Missing HSTS Header <!-- 參考 -->

- Route every `fetch()` through the project's own wrapper; never call bare `fetch()`.
- When you need the Response object (streaming, checking `ok`), parse with `JSON.parse(await resp.text())` and **do not call `resp.json()`**. The scanner treats `.json()` as a taint sink; even `.json().catch(() => ({}))` gets flagged.
- The backend always sends the HSTS header under HTTPS (via middleware).

## 2. Hash, HMAC and token comparison: Observable Time Discrepancy <!-- 參考 -->

- Always use constant-time comparison (`hash_equals($expected, $actual)`), and check the type with `is_string()` first.
- The scanner tracks taint from hash function return values, so **any comparison operator that touches the value gets flagged**:
  - For the null fallback, don't write `$a === $b`; write `is_null($a) && is_null($b)`
  - To check whether an array holding hash values is empty, don't write `$arr === []`; use `empty($arr)`
- Maintenance commands that only run internally get scanned too; "there is no externally observable timing" is not a reason to skip.

## 3. Encryption keys: Use of Hard-coded Cryptographic Key <!-- 參考 -->

- Type key fields as `?string` and return `null` when missing; **do not fall back to literals such as `''` or `str_repeat()`**. Check for null before using the key, and fail immediately if it is null.
- If the scanner still traces the literal default of `config('x.key')` all the way to the decrypt function, read `$_ENV['KEY'] ?? $_SERVER['KEY'] ?? null` instead, and state this pattern's precondition in the docblock (e.g. no config cache in use).
- Generate test keys in setUp with `random_bytes(32)`, and generate the IV randomly too. Don't write `str_repeat('a', 32)` or `"\x00"`.

## 4. Input-controlled loop conditions: Unchecked Input for Loop Condition <!-- 參考 -->

Loops like `while (buf.indexOf(...) !== -1)` that parse external streams or user input need two layers of protection:

1. Rewrite as `for (let i = 0; i < MAX_ITERATIONS; i++)` and `break` when nothing is found.
2. Check a length cap before accumulating into the buffer (e.g. 1 MB for SSE); when exceeded, cancel the read and throw an error.

## 5. File system: Path Traversal <!-- 參考 -->

- Delete directories with the framework's API (e.g. `File::deleteDirectory()`); don't hand-roll recursion with `scandir`, `unlink` and `rmdir`.
- Build paths through the storage abstraction first (e.g. `Storage::disk()->path()`).

## 6. Weak hashes: Use of Weak Hash <!-- 參考 -->

Use `sha256` for cache keys, fingerprints and similar uses as well, not `md5` or `sha1`, even when the purpose is not security.

## 7. Exception handling: Improper Exception Handling <!-- 參考 -->

Wrap CLI command entry points in `try { … } catch (Throwable $e) { log; return FAILURE; }`:

- Catch `Throwable`, not just `Exception`.
- Put the try outside the transaction; don't write the try inside the transaction's closure.

## 8. Hardcoded passwords: Use of Hardcoded Password <!-- 參考 -->

This rule looks at **whether an identifier, array key or object property name contains `password` or `pwd` and is assigned a string literal**, regardless of whether the value looks like a password. Test files, header names, log masking and example values all get flagged.

- Generate test fixture passwords at runtime (`crypto.randomUUID()`, `Str::password()`) and share them via a variable.
- Keep the word password out of identifiers for protocol constants (e.g. the header name used to pass a password). Don't write the literal in the frontend; inject it from a backend constant via `<meta>` or `data-*`.
- For log masking, drop the key entirely (`Arr::except()`) instead of filling in `'***'`.
- **Literals that flow into `opts.password` through a parameter object get flagged too**: the `'admin'` in an e2e `loginAs(page, 'admin')` is treated as a password. Have the login helper take the password only from an environment variable, never from the caller.
