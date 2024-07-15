require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/sms_traffic/version.rb")
loader.enable_reloading
loader.setup

require_relative 'sms_traffic/version'

module SmsTraffic
  class << self
    def configuration
      @configuration ||= Configuration.instance
    end

    def configure(&_block)
      yield(configuration) if block_given?
      configuration.validate!
    end
  end
end
