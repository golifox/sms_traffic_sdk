module SmsTraffic
  class Sms
    attr_accessor :phone, :message, :originator
    attr_reader :id, :status, :errors

    def initialize(phone, message, originator: nil)
      @phone      = phone
      @message    = message
      @originator = originator || SmsTraffic.configuration.originator
      @status     = 'not-sent'
      @errors     = []
      validate!
    end

    def deliver # rubocop:disable Metrics/MethodLength
      # @type [Client::Response]
      response = Client.deliver(phone, message, originator)

      unless response.success?
        @errors << response.error_description
        return false
      end

      # @type [Client::Response::Reply]
      reply = response.reply

      if reply.ok?
        @status = 'sent'
        @id     = reply.sms_id || reply.sms_ids.values.first
        true
      else
        @errors << (reply.error_description || 'Sms has been not enqueued')
        false
      end
    end

    def update_status
      return status if id.nil?

      response = Client.status(id)
      return response.code unless response.success?

      @status = response.reply.status.downcase
    end

    private

    def validate! # rubocop:disable Metrics/ AbcSize
      raise ArgumentError, "Phone should be assigned to #{self.class}." if phone.nil?

      if SmsTraffic.configuration.validate_phone && phone.to_s !~ /^[0-9]{11,}$/
        raise ArgumentError, 'Phone number should contain only numbers. Minimum length is 11.'
      end

      raise ArgumentError, "Message should be specified to #{self.class}." if message.nil?
      raise ArgumentError, "Originator should be specified to #{self.class}." if originator.nil?
    end
  end
end
