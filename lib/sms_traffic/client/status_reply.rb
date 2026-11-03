module SmsTraffic
  class Client
    class StatusReply < Reply
      NOT_FOUND = /no such message/i

      Entry = Struct.new(
        :sms_id, :status, :status_reported, :error, :submission_date, :send_date, :last_status_change_date,
        keyword_init: true
      ) do
        # @return [Boolean] the provider sent a status element, even an empty one (an intermediate status)
        def status_reported?
          status_reported == true
        end

        def error?
          !error.nil?
        end

        def not_found?
          error? && error.match?(NOT_FOUND)
        end

        def final?
          Status.final?(status)
        end

        def delivered?
          Status.delivered?(status)
        end
      end

      # @return [Array<Entry>]
      def entries
        @entries ||= entry_sources.map { |source| build_entry(source) }
      end

      # @param sms_id [String, nil] required unless the reply has exactly one entry
      # @return [Entry, nil]
      def entry(sms_id = nil)
        return entries.find { |item| item.sms_id.to_s == sms_id.to_s } if sms_id
        return entries.first if entries.size == 1

        raise ArgumentError, 'sms_id is required'
      end

      %i[status error send_date].each do |name|
        define_method(name) { |sms_id = nil| entry(sms_id)&.public_send(name) }
      end

      %i[error? not_found? final? delivered?].each do |name|
        define_method(name) { |sms_id = nil| entry(sms_id)&.public_send(name) || false }
      end

      # @return [Hash{String => String}] sms_id => status, without nil values
      def statuses
        entries.to_h { |item| [item.sms_id, item.status] }.compact
      end

      # @return [Hash{String => String}] sms_id => error, without nil values
      def errors
        entries.to_h { |item| [item.sms_id, item.error] }.compact
      end

      private

      def entry_sources
        sms = fetch_value(to_h, :sms)
        return sms if sms.is_a?(Array)
        return [sms] if sms.is_a?(Hash)

        to_h.empty? ? [] : [to_h]
      end

      def key?(source, key)
        source.is_a?(Hash) && (source.key?(key.to_s) || source.key?(key.to_sym))
      end

      def blank_to_nil(value)
        stripped = value&.strip
        stripped unless stripped.nil? || stripped.empty?
      end

      def build_entry(source)
        Entry.new(
          sms_id:                  fetch_value(source, :sms_id),
          status:                  fetch_value(source, :status),
          status_reported:         key?(source, :status),
          error:                   blank_to_nil(fetch_value(source, :error)),
          # The provider spells this field "submition_date".
          submission_date:         fetch_value(source, :submition_date),
          send_date:               fetch_value(source, :send_date),
          last_status_change_date: fetch_value(source, :last_status_change_date)
        )
      end
    end
  end
end
