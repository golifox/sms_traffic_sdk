# SmsTraffic

[![Gem Version](https://badge.fury.io/rb/sms_traffic_sdk.svg)](https://badge.fury.io/rb/sms_traffic_sdk)
[![Maintainability](https://api.codeclimate.com/v1/badges/bb4795be5024dd81d927/maintainability)](https://codeclimate.com/github/golifox/sms_traffic/maintainability)
[![Coverage](https://codecov.io/github/golifox/sms_traffic/graph/badge.svg?token=74C0YBJP3F)](https://codecov.io/github/golifox/sms_traffic)
[![CI](https://github.com/golifox/sms_traffic/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/golifox/sms_traffic/actions/workflows/ci.yml)

Ruby Gem as a software development kit (SDK) that facilitates interaction with the SMS Traffic HTTP API (smstraffic.ru/api).
This gem provides a convenient wrapper to integrate SMS Traffic services within Ruby applications, allowing for easy 
sending of SMS messages фтв checking delivery statuses.

## Features

- Send SMS messages to single or multiple recipients.
- Check the delivery status of sent messages.
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
# initializers/sms_traffic.rb
require 'sms_traffic_sdk'

SmsTraffic.configure do |config|
  config.login = 'login'
  config.password = 'password'
  config.originator = 'default_originator'
  config.server = 'https://api.smstraffic.ru'
  config.debug = true
  config.debugger = Rails.logger
end
```

Initialize sms:
```ruby
sms = SmsTraffic::Sms.new('phone', 'text', 'originator') # initialize sms, originator by default from settings
# =>  #<SmsTraffic::Sms:0x0000 @errors=[], @message="text", @originator="default_originator", @phone="phone", @status="not-sent">

```

Send it and get sent sms id and dispatch code:
```ruby
sms.deliver # send sms. returns sms id or dispatch code if something went wrong
# => true
sms.id # get sms id
# => '123456789'
```

Get current sms status and update it:
```ruby
sms.status # get sms delivery status
# => 'sent'
sms.update_status # updates sms delivery status. returns status or status check response code on error
# => 'delivered'
```

Get any sms status:
```ruby
response = SmsTraffic.status(sms_id) # status - sms delivery status unless error or return error
reply = response.reply
# => #<SmsTraffic::Client::StatusReply:0x0000>
status = reply.status
# => "Delivered"
reply.hash
# => 
# {"error"=>nil,
#  "submition_date"=>"2024-07-15 11:36:25",
#  "send_date"=>"2024-07-15 11:36:25",
#  "last_status_change_date"=>"2024-07-15 11:36:25",
#  "sms_id"=>"865149797164801235",
#  "status"=>"Delivered"}

```

# Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/golifox/sms_traffic_sdk. 

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## License

The gem is available as open-source under the terms of the [MIT License](LICENSE).

## Contact

If you have any questions or feedback regarding SMS Traffic SDK, please feel free to contact us via GitHub issues or directly by email at your-email@example.com.

## Acknowledgments

- Thanks to the SMS Traffic team for providing the API that this gem is based upon.
- Anyone who contributes to this project is greatly appreciated.

For more information please visit [SMS Traffic API docs](http://smstraffic.ru/api).

