module SmsTraffic
  # Provider delivery statuses (HTTP API v1, operation=status).
  module Status
    INTERMEDIATE = ['', 'Buffered SMSC'].freeze
    DELIVERED = 'Delivered'.freeze
    FINAL = [DELIVERED, 'Non Delivered', 'Rejected', 'Expired', 'Deleted', 'Unknown status'].freeze

    class << self
      # @param status [String, nil] provider status, compared case-insensitively
      def final?(status)
        matches?(FINAL, status)
      end

      def delivered?(status)
        matches?([DELIVERED], status)
      end

      private

      def matches?(list, status)
        value = status.to_s.strip
        list.any? { |item| item.casecmp?(value) }
      end
    end
  end
end
