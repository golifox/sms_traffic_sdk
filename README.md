# SmsTraffic

[![Gem Version](https://badge.fury.io/rb/sms_traffic_sdk.svg)](https://badge.fury.io/rb/sms_traffic_sdk)
[![Maintainability](https://api.codeclimate.com/v1/badges/bb4795be5024dd81d927/maintainability)](https://codeclimate.com/github/golifox/sms_traffic_sdk/maintainability)
[![Coverage](https://codecov.io/github/golifox/sms_traffic_sdk/graph/badge.svg?token=74C0YBJP3F)](https://codecov.io/github/golifox/sms_traffic_sdk)
[![CI](https://github.com/golifox/sms_traffic_sdk/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/golifox/sms_traffic_sdk/actions/workflows/ci.yml)

Ruby client for the [SMS Traffic HTTP API](http://smstraffic.ru/api): send SMS, check delivery statuses, read the
account balance. Typed errors, an optional backup host, and a debug log that never shows credentials, phones or
message text.

- [Installation](#installation)
- [Quick start](#quick-start)
- [Configuration](#configuration)
- [Sending with `SmsTraffic::Sms`](#sending-with-smstrafficsms)
- [Using `SmsTraffic::Client`](#using-smstrafficclient)
- [Statuses](#statuses)
- [Failures and retries](#failures-and-retries)
- [Debug logging](#debug-logging)
- [For AI agents](#for-ai-agents)
- [Development](#development)

## Installation

```ruby
# Gemfile
gem 'sms_traffic_sdk'
```

Requires Ruby 3.1 or newer. No native extensions: XML is parsed by Nori with the pure-Ruby REXML backend.

## Quick start

```ruby
# config/initializers/sms_traffic.rb
SmsTraffic.configure do |config|
  config.login      = ENV.fetch('SMS_TRAFFIC_LOGIN')
  config.password   = ENV.fetch('SMS_TRAFFIC_PASSWORD')
  config.host       = 'https://api.smstraffic.ru'
  config.originator = 'my_brand'
end

sms = SmsTraffic::Sms.new('79991112233', 'Your code is 1234')
sms.deliver        # => true when the provider queued it
sms.id             # => '8287366071'

sms.update_status  # => 'delivered'
sms.delivered?     # => true
```

Outside Bundler, load the gem with `require 'sms_traffic'`.

## Configuration

| Setting          | Default       | Notes                                                                   |
| ---------------- | ------------- | ----------------------------------------------------------------------- |
| `login`          | —             | Required.                                                               |
| `password`       | —             | Required.                                                               |
| `host`           | —             | Required, e.g. `https://api.smstraffic.ru`.                             |
| `fallback_host`  | `nil`         | Backup host, e.g. `https://api2.smstraffic.ru`. See [retries](#failures-and-retries). |
| `originator`     | `nil`         | Default sender name; can also be given per SMS.                         |
| `open_timeout`   | `10`          | Seconds.                                                                |
| `read_timeout`   | `30`          | Seconds.                                                                |
| `validate_phone` | `true`        | `Sms.new` requires 11 or more digits.                                   |
| `debug`          | `false`       | Writes one request line and one response line per call.                 |
| `logger`         | `nil`         | Required when `debug` is `true`, e.g. `Rails.logger`.                   |
| `xml_parser`     | Nori + REXML  | Any object with `parse(xml)` that returns a Hash.                       |

`SmsTraffic.configure` raises `ArgumentError` when a required setting is missing.

## Sending with `SmsTraffic::Sms`

`Sms` is the high-level object for one message. It **never raises** on network, HTTP or provider failures: it
returns `false` (or keeps the status) and appends the error message to `errors`.

```ruby
sms = SmsTraffic::Sms.new('79991112233', 'text', originator: 'my_brand')

sms.deliver   # => true / false
sms.status    # => 'sent' after a successful deliver, 'not-sent' before
sms.id        # => provider sms id, nil until sent
sms.reply     # => SmsTraffic::Client::DeliverReply of the last deliver
sms.errors    # => [] or e.g. ['412: wrong IP'], ['Malformed reply (42 bytes)']

sms.update_status # => current status, downcased ('delivered'); unchanged on failure
sms.final?        # => true for a final provider status
sms.delivered?    # => true only for 'delivered'
```

`Sms.new` raises `ArgumentError` for a missing phone, message or originator, and for a phone that fails
`validate_phone`.

## Using `SmsTraffic::Client`

The low-level client returns reply objects and **raises** [typed errors](#failures-and-retries).

```ruby
# Several phones are comma-separated. Extra keyword options are sent to the provider as is.
reply = SmsTraffic::Client.deliver('79991112233,79261112233', 'text', 'my_brand')
reply.ok?                    # => true: result OK and at least one message queued
reply.sms_ids                # => ['8287366071', '8287366073']
reply.messages               # => [{ phone: '79991112233', sms_id: '8287366071', push_id: 'a' }, ...]
reply.sms_id('79261112233')  # => first sms id for the phone

reply = SmsTraffic::Client.status('8287713301', '8287713303')
reply.statuses               # => { '8287713301' => 'Delivered' }
reply.errors                 # => { '8287713303' => 'no such message or this message does not belong to you' }
reply.status('8287713301')   # => 'Delivered' (the id may be omitted when there is one entry)
reply.entry('8287713303').not_found? # => true

SmsTraffic::Client.balance.balance # => 0.10025e5 (BigDecimal), nil when absent or not a number
```

A status entry has `sms_id`, `status`, `error`, `submission_date`, `send_date`, `last_status_change_date` (strings as
sent by the provider) and the predicates `error?`, `not_found?`, `final?`, `delivered?` and `status_reported?` (true
when the provider sent a status element, even an empty one). The balance is returned in the provider's units, which
are not documented.

Every reply exposes the parsed body as `to_h`.

## Statuses

| Kind         | Provider statuses                                                                 |
| ------------ | --------------------------------------------------------------------------------- |
| Final        | `Delivered`, `Non Delivered`, `Rejected`, `Expired`, `Deleted`, `Unknown status`  |
| Intermediate | empty status, `Buffered SMSC`                                                     |

Comparison is case-insensitive. The lists are `SmsTraffic::Status::FINAL` and `SmsTraffic::Status::INTERMEDIATE`.
`final?` and `delivered?` exist on `Sms`, `StatusReply` (pass an sms id when there are several entries) and each
entry. An empty status keeps `Sms#status` unchanged.

## Failures and retries

All errors inherit from `SmsTraffic::Error`.

| Error                             | When                                                             | Data                       |
| --------------------------------- | ---------------------------------------------------------------- | -------------------------- |
| `SmsTraffic::ConnectionError`     | Network, timeout or TLS failure                                  | `cause` (original error)   |
| `SmsTraffic::HttpError`           | Non-2xx response                                                 | `status`, `body`           |
| `SmsTraffic::MalformedReplyError` | 2xx body that is not an XML `<reply>` (HTML page, text, truncated or empty body) | `body`; the message gives only its size |
| `SmsTraffic::ApiError`            | Provider replied `ERROR` (or `ERRO`)                             | `code`, `description`      |

`ApiError` also has `retryable?` (1000), `access_denied?` (411, 412), `insufficient_funds?` (415) and
`blocked_phone?` (432).

With `fallback_host` set, a failed request is repeated **once** on the backup host, and the error of the last
attempt is raised. `deliver` is repeated only when the provider surely did not receive the request, so an SMS is
never sent twice:

| Failure                                                                                   | `deliver` | `status`, `balance` |
| ----------------------------------------------------------------------------------------- | --------- | ------------------- |
| Server not reached: `SocketError`, `ECONNREFUSED`, `EHOSTUNREACH`, `ENETUNREACH`, `Net::OpenTimeout` | retried   | retried             |
| Other `ConnectionError`: read timeout, reset connection, TLS failure                      | —         | retried             |
| HTTP 5xx                                                                                  | —         | retried             |
| `MalformedReplyError`                                                                     | —         | retried             |
| API error 1000 (temporary server problem)                                                 | retried   | retried             |
| Other HTTP or API errors                                                                  | —         | —                   |

```ruby
begin
  SmsTraffic::Client.deliver('79991112233', 'text')
rescue SmsTraffic::ApiError => e
  e.code        # => '401'
  e.description # => 'login param is missing'
rescue SmsTraffic::Error => e
  e.message
end
```

## Debug logging

With `debug = true`, each call writes through `logger.debug` one request line and one response line (status and body
size, never the body). Only `originator`, `want_sms_ids`, `rus`, `operation` and `sms_id` are shown; every other
param, including `login`, `password`, `phones`, `message` and extra options, is `[FILTERED]`. A fallback retry adds
one line naming the host and the error class.

## For AI agents

Integration contract in short form; the sections above have the details.

- **Entry points.** `SmsTraffic.configure`, `SmsTraffic::Sms` (high level) and `SmsTraffic::Client.deliver`,
  `.status`, `.balance` (low level). Nothing else is public API.
- **Raising.** `Sms#deliver` and `Sms#update_status` never raise `SmsTraffic::Error`; read the boolean result, `status`
  and `errors`. `Client.*` always raise a `SmsTraffic::Error` subclass on failure; rescue `SmsTraffic::Error` to cover
  them all. `ArgumentError` comes only from `configure` and `Sms.new`.
- **Success.** `DeliverReply#ok?` is true only when at least one message was queued; a non-error reply that queued
  nothing is not `ok?` and has `error_description`.
- **Duplicates.** Do not wrap `deliver` in your own retry on a timeout or HTTP 5xx: the provider may already have
  queued the SMS. The built-in fallback already retries only safe cases.
- **Statuses** are provider strings (`'Delivered'`) on replies and downcased strings (`'delivered'`) on `Sms`. Use
  `final?` to stop polling and `delivered?` for success instead of comparing strings.
- **Ids** are strings. Phones are digit strings without `+`; several phones in one `Client.deliver` are
  comma-separated.
- **Tests.** Stub `POST <host>/multi.php` (for example with WebMock) and return an XML `<reply>` body. Any 2xx body
  without `<reply>` raises `MalformedReplyError`; an empty `<reply/>` is an empty reply.
- **Secrets.** The gem never logs credentials, phones, message text or response bodies; keep it that way when adding
  params by extending `SmsTraffic::Client::LOGGED_PARAMS` only with non-sensitive keys.

## Development

```sh
bin/setup                                            # install dependencies
bundle exec rake                                     # RSpec and RuboCop
BUNDLE_GEMFILE=gemfiles/minimum.gemfile bundle exec rspec  # lowest supported dependency versions
bin/console                                          # interactive prompt
```

Bug reports and pull requests are welcome in [GitHub issues](https://github.com/golifox/sms_traffic_sdk/issues).
Changes are listed in the [CHANGELOG](CHANGELOG.md).

## License

Available as open source under the [MIT License](LICENSE). Thanks to the SMS Traffic team for the API.
