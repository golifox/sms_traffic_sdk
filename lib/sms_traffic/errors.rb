module SmsTraffic
  class Error < StandardError; end

  # Network or TLS failure; the original exception is available as +cause+.
  class ConnectionError < Error; end

  # Non-2xx HTTP status.
  class HttpError < Error
    attr_reader :status, :body

    def initialize(status, body)
      @status = status
      @body   = body
      super("HTTP #{status}")
    end
  end

  # HTTP 200 reply whose result is ERROR.
  class ApiError < Error
    attr_reader :code, :description

    def initialize(code, description)
      @code        = code
      @description = description
      super("#{code}: #{description}")
    end
  end
end
