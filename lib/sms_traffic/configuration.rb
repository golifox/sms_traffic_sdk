require 'nori'

module SmsTraffic
  class Configuration
    ATTRIBUTES = %i[
      login password host originator debug logger open_timeout read_timeout validate_phone xml_parser
    ].freeze

    attr_accessor(*ATTRIBUTES)

    def initialize
      reset!
    end

    def reset!
      self.login          = nil
      self.password       = nil
      self.host           = nil
      self.originator     = nil
      self.debug          = false
      self.logger         = nil
      self.open_timeout   = 10
      self.read_timeout   = 30
      self.validate_phone = true
      self.xml_parser     = Nori.new(advanced_typecasting: false)
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
