require 'singleton'
require 'nori'

module SmsTraffic
  class Configuration
    include Singleton

    attr_accessor :login, :password, :host, :originator, :debug, :logger, :xml_parser

    def initialize
      self.debug = default_configuration[:debug]
      self.logger = default_configuration[:logger]
      self.xml_parser = default_configuration[:xml_parser]
      super
    end

    def reset!
      default_configuration.each do |key, value|
        send("#{key}=", value)
      end
    end

    def validate!
      validation_rules.each do |key, value|
        raise ArgumentError, "#{key} should be defined for #{self}." if value.nil?
      end
    end

    def to_h
      {
        login:      login,
        password:   password,
        host:       host,
        originator: originator,
        debug:      debug,
        logger:     logger,
        xml_parser: xml_parser
      }
    end

    def values_at(*keys)
      to_h.values_at(*keys)
    end

    private

    def default_configuration
      {
        login:      nil,
        password:   nil,
        host:       nil,
        originator: nil,
        debug:      false,
        logger:     $stdout,
        xml_parser: default_xml_parser
      }
    end

    def validation_rules
      {
        'Login'        => login,
        'Password'     => password,
        'Server'       => host,
        'Originator'   => originator,
        'Debug logger' => debug && !logger ? nil : true
      }
    end

    def default_xml_parser
      @default_xml_parser ||= Nori.new(advanced_typecasting: true).freeze
    end
  end
end
