# sms_traffic_sdk 0.2.0: v1 API additions

Status: ready for implementation
Delivery target: main, then GitHub Release `v0.2.0` (publishes through CI)
Task branch: release-0.2.0
Review tier: fable
Gate: `bundle exec rake` (RSpec + RuboCop 1.92), `bundle exec rake build`, packaged-gem load in a plain Ruby process

## Context

Source: provider docs https://www.smstraffic.ru/api/ (HTTP API v1, `multi.php`), read 2026-11-03.
Provider statements used here:
- Error replies: the format section says `result = ERROR`, the example shows `<result>ERRO</result>`.
- Backup server `api2.smstraffic.ru/multi.php` for connection problems; error `1000` = temporary server
  problem, retry later or send to the backup server.
- `operation=account` reply: `<reply><account>10025</account></reply>` (units not stated).
- Statuses: intermediate = empty string, `Buffered SMSC`; final = `Delivered`, `Non Delivered`, `Rejected`,
  `Expired`, `Deleted`, `Unknown status`.
- Error codes: 411 invalid login/password, 412 invalid IP, 415 insufficient funds, 432 blocked phone, 1000 temporary.

0.2.0 is additive: no public method is removed or changes its return type.

## Required behavior

1. **API error detection.** `Reply#api_error?` is true when `result` is present and is not `OK` (covers `ERROR`
   and `ERRO`). Replies without `result` (status, account) are not errors. Add a fixture with `ERRO`.
2. **Backup host.** `Configuration#fallback_host` (default nil). When set, `Client` repeats a request once on
   `fallback_host` when:
   - the request could not reach the server: `SocketError`, `Errno::ECONNREFUSED`, `Errno::EHOSTUNREACH`,
     `Errno::ENETUNREACH`, `Net::OpenTimeout`; or
   - the reply is an `ApiError` with code 1000.
   `Client.status` and `Client.balance` (read-only) also retry on any `ConnectionError` and on HTTP 5xx.
   `Client.deliver` never retries after a read timeout, a reset connection, or an HTTP 5xx, since the provider
   may already have queued the SMS. The final error is the one from the last attempt. With `debug`, the retry is
   logged in one line without credentials.
3. **Balance.** `Client.balance` posts `operation=account` and returns an `AccountReply`; `AccountReply#balance`
   is a `BigDecimal` from `<account>` (nil when absent). Units are not converted. Add `bigdecimal` as a runtime
   dependency (bundled, not default, since Ruby 3.4).
4. **Status classification.** `SmsTraffic::Status` holds `FINAL` and `INTERMEDIATE` provider values.
   `StatusReply::Entry#final?` and `#delivered?`; `StatusReply` delegates both like `status` (optional `sms_id`).
   `Sms#final?` and `Sms#delivered?` compare the stored (downcased) status, case-insensitively.
   `not-sent` and `sent` are neither final nor delivered.
5. **ApiError predicates.** `retryable?` (1000), `access_denied?` (411, 412), `insufficient_funds?` (415),
   `blocked_phone?` (432). `code` keeps its current value; predicates compare `code.to_i`.
6. **Tests.** WebMock end to end through `Client` and `Sms`: fallback success, fallback not used for deliver after
   read timeout and 5xx, fallback used for status after read timeout, no fallback when unset, code-1000 retry,
   `ERRO` raising `ApiError`, balance parsing, every status value classified, predicates.
7. **Docs and release.** README sections for `fallback_host`, `balance`, `final?`/`delivered?`, error predicates.
   CHANGELOG `0.2.0 - 2026-11-03` (Added, Fixed). `VERSION = '0.2.0'`.

## Out of scope
- HTTP API v2, DLR callback parsing, typed send options, instance-based client.
