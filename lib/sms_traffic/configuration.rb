require 'nori'

module SmsTraffic
  class Configuration
    ATTRIBUTES = %i[
      login password host fallback_host originator debug logger open_timeout read_timeout validate_phone xml_parser
    ].freeze

    # Attributes not listed here default to nil.
    DEFAULTS = { debug: false, open_timeout: 10, read_timeout: 30, validate_phone: true }.freeze

    attr_accessor(*ATTRIBUTES)

    def initialize
      reset!
    end

    def reset!
      ATTRIBUTES.each { |attribute| public_send("#{attribute}=", DEFAULTS[attribute]) }
      self.xml_parser = Nori.new(advanced_typecasting: false, parser: :rexml)
    end

    def validate!
      raise ArgumentError, 'login should be defined' if login.nil?
      raise ArgumentError, 'password should be defined' if password.nil?
      raise ArgumentError, 'host should be defined' if host.nil?
      raise ArgumentError, 'logger should be defined when debug is enabled' if debug && logger.nil?
    end

    def to_h
      ATTRIBUTES.to_h { |attribute| [attribute, public_send(attribute)] }
    end
  end
end
