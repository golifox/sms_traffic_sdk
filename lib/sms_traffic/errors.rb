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

  # HTTP 200 body that is not an XML `<reply>` element: an HTML error page, plain text, a truncated reply.
  class MalformedReplyError < Error
    attr_reader :body

    def initialize(body)
      @body = body
      super("Malformed reply (#{body.to_s.bytesize} bytes)")
    end
  end

  # HTTP 200 reply whose `result` is not `OK` (`ERROR`, `ERRO`).
  class ApiError < Error
    attr_reader :code, :description

    def initialize(code, description)
      @code        = code
      @description = description
      super("#{code}: #{description}")
    end

    # Temporary server problem: retry later or use the backup host.
    def retryable?
      code.to_i == 1000
    end

    def access_denied?
      [411, 412].include?(code.to_i)
    end

    def insufficient_funds?
      code.to_i == 415
    end

    def blocked_phone?
      code.to_i == 432
    end
  end
end
