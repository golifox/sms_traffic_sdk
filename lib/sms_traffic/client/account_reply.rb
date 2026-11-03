require 'bigdecimal'

module SmsTraffic
  class Client
    class AccountReply < Reply
      # @return [BigDecimal, nil] account balance as sent by the provider (units are not converted); nil when absent
      #   or not a number
      def balance
        value = fetch_value(to_h, :account).to_s.strip
        BigDecimal(value, exception: false) unless value.empty?
      end
    end
  end
end
