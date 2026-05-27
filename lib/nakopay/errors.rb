module NakoPay
  # Base error for everything raised by this SDK.
  class Error < StandardError; end

  # Raised for any non-2xx HTTP response.
  class APIError < Error
    attr_reader :code, :type, :param, :doc_url, :request_id, :status_code

    def initialize(message:, code: nil, type: nil, param: nil, doc_url: nil, request_id: nil, status_code: nil)
      super(message)
      @code = code
      @type = type
      @param = param
      @doc_url = doc_url
      @request_id = request_id
      @status_code = status_code
    end

    # True for 429/5xx errors that may succeed on retry.
    def retryable?
      @status_code == 429 || (@status_code && @status_code >= 500)
    end
  end

  # Raised for 401 or authentication_error codes.
  class AuthenticationError < APIError
    def initialize(message: "Invalid API key", **kwargs)
      kwargs[:code] ||= "authentication_error"
      kwargs[:type] ||= "authentication_error"
      super(message: message, **kwargs)
    end
  end

  # Raised for 429 responses after all retries are exhausted.
  class RateLimitError < APIError
    def initialize(message: "Rate limit exceeded", **kwargs)
      kwargs[:code] ||= "rate_limit_error"
      kwargs[:type] ||= "rate_limit_error"
      super(message: message, **kwargs)
    end
  end

  # Raised when an idempotency key is reused with different parameters.
  class IdempotencyError < APIError
    def initialize(message: "Idempotency conflict", **kwargs)
      kwargs[:code] ||= "idempotency_error"
      kwargs[:type] ||= "idempotency_error"
      super(message: message, **kwargs)
    end
  end

  # Raised when transport fails (DNS, refused, timeout) after all retries.
  class ConnectionError < Error; end

  # Raised by Webhook.construct_event when verification fails.
  class SignatureVerificationError < Error
    attr_reader :code

    def initialize(message, code: nil)
      super(message)
      @code = code
    end
  end

  # Maps API error envelope to specialized subclass.
  def self.build_api_error(payload, status_code:)
    code = payload["code"]
    message = payload["message"]
    common = {
      code: code,
      type: payload["type"],
      param: payload["param"],
      doc_url: payload["doc_url"],
      request_id: payload["request_id"],
      status_code: status_code,
    }

    if status_code == 401 || code == "authentication_error"
      AuthenticationError.new(message: message || "Invalid API key", **common)
    elsif status_code == 429 || code == "rate_limit_error"
      RateLimitError.new(message: message || "Rate limit exceeded", **common)
    elsif code == "idempotency_error"
      IdempotencyError.new(message: message || "Idempotency conflict", **common)
    else
      APIError.new(message: message || "Unknown error", **common)
    end
  end
end
