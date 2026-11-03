# Changelog

## 0.1.0 - 2026-11-03

### Breaking changes

- Ruby 3.1 or newer is required.
- Zeitwerk is no longer a dependency; files are loaded with `require_relative`.
- `SmsTraffic::Configuration` is a plain class, not a `Singleton`. Defaults changed: `logger` is `nil` (was `$stdout`),
  new `open_timeout` (10) and `read_timeout` (30). `originator` is no longer required by `configure`.
  `Configuration#values_at` is removed.
- `SmsTraffic::Client::Response` is removed. `Client.deliver` returns a `DeliverReply` and `Client.status` a
  `StatusReply` directly, and raise `SmsTraffic::ConnectionError`, `SmsTraffic::HttpError` or `SmsTraffic::ApiError`
  (all `SmsTraffic::Error`) instead of returning a failed response.
- `Reply#hash` no longer returns the parsed reply (it is `Object#hash` again); use `Reply#to_h`.
- `DeliverReply#ok?` is strictly boolean and requires a queued message. `#sms_ids` is an Array of every sms id (it was
  a Hash keyed by phone). `#message_infos` is replaced by `#messages`. `#error_description` reads
  `"Sms has not been enqueued: <description>"`.
- `StatusReply#sms_array` is replaced by `#entries` (`StatusReply::Entry`); `#entry`, `#error?`, `#not_found?`
  and `#send_date` are new.
- `Sms#response` is replaced by `Sms#reply`. `Sms#update_status` always returns the status String, and `Sms#deliver`
  records `SmsTraffic::Error`s in `errors` instead of the HTTP code.
- The `konsierge-sms.rb` executable is removed.

### Fixed

- `Sms` phone validation no longer accepts a newline-separated value (`\A`/`\z` anchors).
- `Client.status` with several ids sends a flat comma-separated `sms_id` list.
- The client builds its URI from the current `host` on every request instead of memoizing the first one.
- `open_timeout` and `read_timeout` are applied to every request.
- `Reply` no longer mutates (or fails on) frozen input.
- A multi-part SMS keeps every `sms_id`; a single `<message_info>` with a phone is parsed.
- `require 'sms_traffic_sdk'` works with `Bundler.require`.

### Changed

- CI runs lint and RSpec on Ruby 3.1-3.4, uploads Cobertura coverage to Codecov, and publishes to RubyGems from a
  published release whose tag matches the gem version. The gem package contains only `lib`, `README.md`, `LICENSE`
  and `CHANGELOG.md`.

### Security

- `Net::HTTP#set_debug_output` is no longer used, so the login, password and SMS text are never written to the logger.
  Debug logging emits one request and one response line with `login`, `password` and `message` filtered.

### Migration

- Replace `Client.deliver(...).reply` / `.success?` with the returned reply and `rescue SmsTraffic::Error`.
- Replace `reply.hash` with `reply.to_h`, and `sms.response` with `sms.reply`.
- Treat `reply.sms_ids` as an Array; use `reply.messages` for per-phone data.
- Set `config.logger` explicitly if you relied on the `$stdout` default with `debug = true`.
- `Client.deliver` and `Client.status` no longer raise `SocketError`, `SystemCallError` (`Errno::*`), `IOError`,
  `Net::OpenTimeout`, `Net::ReadTimeout` or `OpenSSL::SSL::SSLError`; rescue `SmsTraffic::ConnectionError` (the
  original exception is in `cause`). `Sms#deliver` and `Sms#update_status` already rescue `SmsTraffic::Error` into
  `errors`.
- Replace `response.as_json` / `sms.response.as_json` with `reply.to_h` / `sms.reply&.to_h`.
- Replace `response.success?` checks with `rescue SmsTraffic::Error`.
- Replace `reply.hash["send_date"]` / `reply.hash["status"]` with `reply.send_date` / `reply.status`.
- The default XML parser no longer typecasts: values such as dates and `true` stay provider strings
  (`Nori.new(advanced_typecasting: false)`).
