require_relative 'sms_traffic/version'
require_relative 'sms_traffic/errors'
require_relative 'sms_traffic/configuration'
require_relative 'sms_traffic/client'
require_relative 'sms_traffic/sms'

module SmsTraffic
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration.validate!
    end
  end
end
