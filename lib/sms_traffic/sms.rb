module SmsTraffic
  class Sms
    PHONE_FORMAT = /\A\d{11,}\z/

    attr_accessor :phone, :message, :originator
    attr_reader :id, :status, :errors, :reply

    def initialize(phone, message, originator: nil)
      @phone      = phone
      @message    = message
      @originator = originator || SmsTraffic.configuration.originator
      @reply      = nil
      @status     = 'not-sent'
      @errors     = []
      validate!
    end

    # @return [Boolean] true when the provider enqueued the sms
    def deliver
      @reply = Client.deliver(phone, message, originator)

      reply.ok? ? mark_sent : add_error(reply.error_description)
      reply.ok?
    rescue SmsTraffic::Error => e
      add_error(e.message)
      false
    end

    # @return [String] the current status; unchanged when the check fails
    def update_status
      return status if id.nil?

      apply_entry(Client.status(id).entry(id))
      status
    rescue SmsTraffic::Error => e
      add_error(e.message)
      status
    end

    private

    def mark_sent
      @status = 'sent'
      @id     = reply.sms_id
    end

    def add_error(error)
      @errors << error
    end

    def apply_entry(entry)
      if entry&.error?
        add_error(entry.error)
      elsif entry&.status
        @status = entry.status.downcase
      else
        add_error("No status returned for sms #{id}")
      end
    end

    def validate! # rubocop:disable Metrics/AbcSize
      raise ArgumentError, "Phone should be assigned to #{self.class}." if phone.nil?

      if SmsTraffic.configuration.validate_phone && !PHONE_FORMAT.match?(phone.to_s)
        raise ArgumentError, 'Phone number should contain only numbers. Minimum length is 11.'
      end

      raise ArgumentError, "Message should be specified to #{self.class}." if message.nil?
      raise ArgumentError, "Originator should be specified to #{self.class}." if originator.nil?
    end
  end
end
