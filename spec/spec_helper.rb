require 'simplecov'
SimpleCov.start { add_filter '/spec/' }

# Additional requires
require 'webmock/rspec'
WebMock.disable_net_connect!

# Local requires
require 'sms_traffic'
require 'sms_traffic/version'

# Spec support
support_dir = File.expand_path('support/**/*.rb', __dir__)
Dir.glob(support_dir).sort.each { |file| require file }

# RSpec configuration
RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) { SmsTraffic.configuration.reset! }
end
