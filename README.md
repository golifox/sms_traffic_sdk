# SmsTraffic

[![Gem Version](https://badge.fury.io/rb/sms_traffic_sdk.svg)](https://badge.fury.io/rb/sms_traffic_sdk)
[![Maintainability](https://api.codeclimate.com/v1/badges/bb4795be5024dd81d927/maintainability)](https://codeclimate.com/github/golifox/sms_traffic_sdk/maintainability)
[![Coverage](https://codecov.io/github/golifox/sms_traffic_sdk/graph/badge.svg?token=74C0YBJP3F)](https://codecov.io/github/golifox/sms_traffic_sdk)
[![CI](https://github.com/golifox/sms_traffic_sdk/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/golifox/sms_traffic_sdk/actions/workflows/ci.yml)

Ruby Gem as a software development kit (SDK) that facilitates interaction with the SMS Traffic HTTP API (smstraffic.ru/api).
This gem provides a convenient wrapper to integrate SMS Traffic services within Ruby applications, allowing for easy 
sending of SMS messages and checking delivery statuses.

## Features

- Send SMS messages to single or multiple recipients.
- Check the delivery status of sent messages.
- Read the account balance.
- Fail over to the provider's backup host.
- **TODO:** Support for various message formats and encodings.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sms_traffic_sdk'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sms_traffic_sdk

## Usage

Define settings:

```ruby
# config/initializers/sms_traffic.rb
require 'sms_traffic'

SmsTraffic.configure do |config|
  config.login          = 'login'
  config.password       = 'password'
  config.host           = 'https://api.smstraffic.ru'
  config.fallback_host  = 'https://api2.smstraffic.ru' # optional backup host, default nil
  config.originator     = 'default_originator' # optional, can be given per SMS
  config.open_timeout   = 10                   # seconds, default 10
  config.read_timeout   = 30                   # seconds, default 30
  config.validate_phone = true                 # default true: 11+ digits
  config.debug          = true                 # default false
  config.logger         = Rails.logger         # required when debug is true
end
```

`login`, `password` and `host` are required; `logger` is required when `debug` is enabled.
With `debug` on, one request line and one response line are written through `logger.debug`;
`login`, `password` and `message` are replaced with `[FILTERED]`.

Send an SMS:

```ruby
sms = SmsTraffic::Sms.new('79991112233', 'text', originator: 'my_brand') # originator defaults to the configured one

sms.deliver      # => true when the provider enqueued it, false otherwise
sms.status       # => 'sent' ('not-sent' until delivered)
sms.id           # => '123456789' (the first sms id of the reply)
sms.reply        # => #<SmsTraffic::Client::DeliverReply>
sms.errors       # => [] (messages of failed attempts)
```

`deliver` and `update_status` never raise on provider or network failures; they append the message to `errors`
and keep the current `status`.

Refresh the status:

```ruby
sms.update_status # => 'delivered' (downcased provider status, or the unchanged status on failure)
```

Use the client directly. It raises typed errors:

```ruby
reply = SmsTraffic::Client.deliver('79991112233,79261112233', 'text', 'my_brand')
reply.ok?        # => true
reply.sms_ids    # => ['8287366071', '8287366073']
reply.messages   # => [{ phone: '79991112233', sms_id: '8287366071', push_id: 'a' }, ...]
reply.sms_id('79261112233') # first sms id for the phone

reply = SmsTraffic::Client.status('8287713301', '8287713303')
reply.entries    # => [#<struct SmsTraffic::Client::StatusReply::Entry sms_id="8287713301", status="Delivered", ...>]
reply.statuses   # => { '8287713301' => 'Delivered' }
reply.errors     # => { '8287713303' => 'no such message or this message does not belong to you' }
reply.entry('8287713303').not_found? # => true
reply.status('8287713301')           # => 'Delivered'; the id may be omitted when there is one entry
```

Each entry has `sms_id`, `status`, `error`, `submission_date`, `send_date`, `last_status_change_date`
(strings as sent by the provider), `error?`, `not_found?`, `final?`, `delivered?` and `status_reported?`
(true when the provider sent a status element, even an empty one).

### Final and delivered statuses

Provider statuses `Delivered`, `Non Delivered`, `Rejected`, `Expired`, `Deleted` and `Unknown status` are final;
an empty status and `Buffered SMSC` are intermediate (`SmsTraffic::Status::FINAL` / `INTERMEDIATE`).
Comparison is case-insensitive.

```ruby
reply = SmsTraffic::Client.status('8287713301')
reply.final?     # => true
reply.delivered? # => true; pass an sms id when the reply has several entries
reply.entry.final?

sms.update_status
sms.final?       # => true for a final stored status; false for 'not-sent' and 'sent'
sms.delivered?   # => true only for 'delivered'
```

### Balance

```ruby
SmsTraffic::Client.balance.balance # => 0.10025e5 (BigDecimal), nil when absent or not a number
```

The value is returned as the provider sends it; its units are not documented and are not converted.

### Fallback host

Set `config.fallback_host` (the provider documents `https://api2.smstraffic.ru`) to repeat a failed request once
on the backup host. The request is repeated after `SocketError`, `Errno::ECONNREFUSED`, `Errno::EHOSTUNREACH`,
`Errno::ENETUNREACH`, `Net::OpenTimeout`, or API error 1000 (temporary server problem). `Client.status` and
`Client.balance` also retry after any `ConnectionError` (read timeout, reset connection, TLS failure) and HTTP 5xx.
`Client.deliver` does not, since the provider may already have queued the SMS. The error of the last attempt is raised. With `debug`, the retry is
logged in one line without credentials.

### XML parser

Replies are parsed with Nori and its pure-Ruby REXML backend, so no native extension is needed. To use another
parser, set `config.xml_parser` to any object that responds to `parse(xml)` and returns a Hash.

### Errors

All errors inherit from `SmsTraffic::Error`:

- `SmsTraffic::ConnectionError` - network, timeout or TLS failure (the original exception is `cause`).
- `SmsTraffic::HttpError` - non-2xx response; has `status` and `body`.
- `SmsTraffic::ApiError` - the provider replied `ERROR` (or `ERRO`); has `code` and `description`, and the
  predicates `retryable?` (1000), `access_denied?` (411, 412), `insufficient_funds?` (415) and `blocked_phone?` (432).

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

# Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/golifox/sms_traffic_sdk.

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## License

The gem is available as open-source under the terms of the [MIT License](LICENSE).

## Contact

If you have any questions or feedback regarding SMS Traffic SDK, please feel free to contact us via GitHub issues or directly by email at i@golifox.ru.

## Acknowledgments

- Thanks to the SMS Traffic team for providing the API that this gem is based upon.
- Anyone who contributes to this project is greatly appreciated.

For more information please visit [SMS Traffic API docs](http://smstraffic.ru/api).

