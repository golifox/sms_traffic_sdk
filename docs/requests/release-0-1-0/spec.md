# sms_traffic_sdk 0.1.0: defect fixes, typed errors, CI

Status: ready for implementation
Delivery target: none (prepare release only; push, tag, and publish need separate approval)
Task branch: release-0.1.0
Review tier: fable
Gate: `bundle exec rake` (full RSpec + RuboCop), `bundle exec rake build`, packaged-gem load check

## Context

Review of 0.0.8 (`c2fc17b`) found the defects below. Consumers: `~/dev/konsierge/projects/otp`
(`app/services/sms_message_service.rb`) and `webchat` (`config/initializers/sms_traffic.rb`).
Both `require 'sms_traffic'`. Backward compatibility is not preserved; 0.1.0 is a breaking release
and the CHANGELOG carries a migration note. Consumer repositories are not edited.

## Required behavior

### Packaging and loading
1. Delete `exe/konsierge-sms.rb` (requires a missing file); remove `bindir`/`executables` from the gemspec.
2. Drop Zeitwerk and the `zeitwerk` dependency. `lib/sms_traffic.rb` loads files with `require_relative`.
   Remove the `unless const_defined?(:OK_REPLY)` hack.
3. Add `lib/sms_traffic_sdk.rb` (`require_relative 'sms_traffic'`) so `Bundler.require` of `gem 'sms_traffic_sdk'` works.
4. `required_ruby_version >= 3.1`; RuboCop `TargetRubyVersion: 3.1`. Replace `.tool-versions` with `mise.toml` (ruby 3.3.3).

### Configuration
5. `Configuration` is a plain class (no `Singleton`); `SmsTraffic.configuration` memoizes one instance; `reset!` restores defaults.
6. Defaults: `debug: false`, `logger: nil`, `open_timeout: 10`, `read_timeout: 30`, `validate_phone: true`, `xml_parser: Nori.new(advanced_typecasting: false)`.
7. `validate!` requires login, password, host, and a logger when `debug` is true. It no longer requires `originator` (it can be given per SMS).
8. `to_h` lists every attribute. Remove `values_at` if unused.

### HTTP client (`SmsTraffic::Client`)
9. Never call `Net::HTTP#set_debug_output`. When `debug` is true, log one request line and one response line through
   `logger.debug`, with `password` and `message` replaced by `[FILTERED]`. Logins, passwords, and SMS text never reach the logger.
10. Build the URI from the current `host` on every request (no class-level memoization).
11. Apply `open_timeout` and `read_timeout`.
12. Typed errors, all under `SmsTraffic::Error < StandardError`:
    - `ConnectionError`: wraps `SocketError`, `SystemCallError`, `IOError`, `Net::OpenTimeout`, `Net::ReadTimeout`,
      `OpenSSL::SSL::SSLError` (original kept as `cause`).
    - `HttpError`: non-2xx HTTP status; exposes `status` (Integer) and `body`.
    - `ApiError`: a 200 reply whose `<result>` is `ERROR` (e.g. `spec/fixtures/failure.xml`); exposes `code` and `description`.
13. `Client.deliver(phone, message, originator = nil, **options)` returns a `DeliverReply`; `Client.status(*sms_ids)`
    returns a `StatusReply`. Both raise the errors above. `Client::Response` is removed.
14. Fix the `status_params` splat (pass the array, not a nested array).

### Replies
15. `Reply#initialize` does not mutate its input: `@xml = xml.gsub(/\s+/, ' ')`, parse `@xml`. Frozen input works.
    `Reply#to_h` returns the parsed reply hash (JSON-serializable); `#hash` no longer overrides `Object#hash`.
16. `DeliverReply`:
    - `ok?` is strictly boolean: result `OK` and at least one queued message.
    - `messages`: Array of `{phone:, sms_id:, push_id:}` normalized from one or many `<message_info>` (phone/push_id may be nil).
    - `sms_ids`: Array of every sms_id in reply order (multi-part SMS to one phone keeps every id).
    - `sms_id(phone = nil)`: first sms_id, or the first for that phone.
    - `error_description`: nil when `ok?`; otherwise `"Sms has not been enqueued: <description>"`.
17. `StatusReply` normalizes both reply shapes into entries: top-level single entry (`status/success_single.xml`)
    and one or many `<sms>` elements (`status/failure_single.xml`, `success_multiple.xml`, `success_and_failure_multiple.xml`).
    - `entries`: Array of `StatusReply::Entry` (value object) with `sms_id`, `status`, `error` (stripped, nil when blank),
      `submission_date`, `send_date`, `last_status_change_date` (provider strings, no timezone conversion),
      `error?` (error present), `not_found?` (error matches `/no such message/i`).
    - `entry(sms_id = nil)`: the entry for that id; without an id only when there is exactly one entry, else `ArgumentError`.
    - Delegating readers for the single-entry case: `status`, `error`, `send_date`, `error?`, `not_found?`, each accepting an optional `sms_id`.
    - `statuses` / `errors`: `{sms_id => value}` without nil values.

### `SmsTraffic::Sms`
18. Phone validation uses `/\A\d{11,}\z/`.
19. `deliver`: on success sets `status = 'sent'`, `id = reply.sms_id`, stores `reply`; returns true.
    On `SmsTraffic::Error` or a non-ok reply it appends the message to `errors`, keeps `status`, returns false.
    Attribute `response` is replaced by `reply`.
20. `update_status` always returns the current status String. Without `id` it makes no request.
    On `SmsTraffic::Error` or an entry with `error?`, it appends the error to `errors` and keeps the status;
    otherwise sets `status` to the downcased provider status.

### Tests
21. End-to-end specs for `Sms#deliver` and `Sms#update_status` through WebMock and the XML fixtures (no doubles of gem classes).
22. Fixture and spec for one `<message_info>` that includes `<phone>`.
23. Spec proving that with `debug = true` the logger output contains neither the password nor the SMS text.
24. Specs for each error class, frozen input, the single not-found status reply, and the newline phone bypass.

### Documentation and release
25. README usage matches the real API (configuration names, `Sms.new(phone, message, originator:)`, errors, status entries).
26. Add `CHANGELOG.md` with `0.1.0` (date of release prep): Breaking changes, Fixed, Security, with a migration note for
    `Response`/`reply.hash`/`sms.response` users.
27. `VERSION = '0.1.0'`.

### GitHub CI (`.github/workflows/ci.yml`)
28. `permissions: contents: read` by default; `concurrency` cancels superseded runs per ref.
29. Matrix Ruby 3.1, 3.2, 3.3, 3.4 with `ruby/setup-ruby@v1` `bundler-cache: true`; remove manual bundler installs; `actions/checkout@v4`.
30. Separate lint job (RuboCop, once, Ruby 3.3); test job runs RSpec.
31. Coverage upload works: SimpleCov writes a format Codecov parses (e.g. `simplecov-cobertura` → `coverage/coverage.xml`)
    with `codecov/codecov-action@v5` `files:`; upload only from one matrix entry.
32. Publish job runs on `release: published` only, checks that the release tag (`vX.Y.Z` or `X.Y.Z`) equals
    `SmsTraffic::VERSION`, builds, and pushes with `GEM_HOST_API_KEY`. Trusted publishing is a recommendation in the report,
    not implemented (needs rubygems.org setup).

## Out of scope
- Edits to `otp` or `webchat`; push, tag, RubyGems publish.
