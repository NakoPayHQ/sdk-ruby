require "json"
require "net/http"
require "securerandom"
require "uri"

module NakoPay
  # Low-level HTTP client. Most callers use the resource modules
  # (NakoPay::Invoice, etc.) instead of touching this directly.
  class Client
    DEFAULT_BASE_URL    = "https://api.nakopay.com/v1"
    DEFAULT_API_VERSION = "2025-04-20"
    DEFAULT_TIMEOUT     = 30
    DEFAULT_MAX_RETRIES = 3

    attr_reader :api_key, :base_url, :api_version, :timeout, :max_retries

    # @param faraday [Faraday::Connection, nil] optional Faraday connection for
    #   custom middleware stacks. When provided, Net::HTTP is not used.
    def initialize(api_key: nil, base_url: nil, api_version: nil, timeout: nil, max_retries: nil, faraday: nil)
      @api_key     = api_key     || NakoPay.api_key
      @base_url    = (base_url   || NakoPay.base_url    || DEFAULT_BASE_URL).chomp("/")
      @api_version = api_version || NakoPay.api_version || DEFAULT_API_VERSION
      @timeout     = timeout     || NakoPay.timeout     || DEFAULT_TIMEOUT
      @max_retries = max_retries || NakoPay.max_retries || DEFAULT_MAX_RETRIES
      @faraday     = faraday

      raise ArgumentError, "NakoPay: api_key is required" if @api_key.nil? || @api_key.empty?
      if @api_key.start_with?("pk_")
        raise ArgumentError, "NakoPay: a publishable key (pk_*) was passed to the server SDK; use a secret key (sk_live_* or sk_test_*)"
      end
    end

    def request(method, path, body: nil, query: nil, idempotency_key: nil, headers: {})
      attempt = 0
      loop do
        begin
          code, raw = execute_request(method, path, body: body, query: query, idempotency_key: idempotency_key, headers: headers)
        rescue StandardError => e
          if attempt < @max_retries
            sleep_with_backoff(attempt, nil)
            attempt += 1
            next
          end
          raise NakoPay::ConnectionError, "network error: #{e.message}"
        end

        if code >= 200 && code < 300
          return raw.empty? ? nil : JSON.parse(raw)
        end

        env = (JSON.parse(raw) rescue {})
        api_err_payload = env.is_a?(Hash) ? env["error"] : nil
        api_err_payload ||= { "code" => "http_#{code}", "message" => raw.empty? ? "HTTP #{code}" : raw }

        if (code == 429 || code >= 500) && attempt < @max_retries
          sleep_with_backoff(attempt, nil)
          attempt += 1
          next
        end

        raise NakoPay.build_api_error(api_err_payload, status_code: code)
      end
    end

    private

    def execute_request(method, path, body:, query:, idempotency_key:, headers:)
      if @faraday
        execute_faraday(method, path, body: body, query: query, idempotency_key: idempotency_key, headers: headers)
      else
        execute_net_http(method, path, body: body, query: query, idempotency_key: idempotency_key, headers: headers)
      end
    end

    def execute_net_http(method, path, body:, query:, idempotency_key:, headers:)
      uri = URI(@base_url + path)
      uri.query = URI.encode_www_form(query.compact) if query && !query.empty?

      req = build_request(method, uri, body: body, idempotency_key: idempotency_key, headers: headers)
      res = http_for(uri).request(req)
      [res.code.to_i, res.body.to_s]
    end

    def execute_faraday(method, path, body:, query:, idempotency_key:, headers:)
      url = @base_url + path
      h = default_headers.merge(headers)
      if %w[POST DELETE].include?(method.to_s.upcase)
        h["Idempotency-Key"] = idempotency_key || "idem_#{SecureRandom.hex(16)}"
      end

      resp = @faraday.run_request(method.to_s.downcase.to_sym, url, body ? JSON.generate(body) : nil, h) do |req|
        req.params.update(query.compact) if query && !query.empty?
        req.headers["Content-Type"] = "application/json" if body
      end
      [resp.status, resp.body.to_s]
    end

    def default_headers
      {
        "Authorization"     => "Bearer #{@api_key}",
        "X-NakoPay-Version" => @api_version,
        "User-Agent"        => "nakopay-ruby/#{VERSION}",
        "Accept"            => "application/json",
      }
    end

    def http_for(uri)
      h = Net::HTTP.new(uri.host, uri.port)
      h.use_ssl = uri.scheme == "https"
      h.open_timeout = @timeout
      h.read_timeout = @timeout
      h
    end

    def build_request(method, uri, body:, idempotency_key:, headers:)
      klass = case method.to_s.upcase
              when "GET"    then Net::HTTP::Get
              when "POST"   then Net::HTTP::Post
              when "DELETE" then Net::HTTP::Delete
              else raise ArgumentError, "unsupported method #{method}"
              end
      req = klass.new(uri.request_uri)
      default_headers.each { |k, v| req[k] = v }
      headers.each { |k, v| req[k] = v }

      if %w[POST DELETE].include?(method.to_s.upcase)
        req["Idempotency-Key"] = idempotency_key || "idem_#{SecureRandom.hex(16)}"
        if body
          req["Content-Type"] = "application/json"
          req.body = JSON.generate(body)
        end
      end
      req
    end

    def sleep_with_backoff(attempt, retry_after)
      if retry_after
        n = Integer(retry_after) rescue nil
        return sleep([n, 30].min) if n && n >= 0
      end
      base = [250 * (2**attempt), 8_000].min / 1000.0
      jitter = base * 0.25 * (rand * 2 - 1)
      sleep [0.05, base + jitter].max
    end
  end

  class << self
    attr_accessor :api_key, :base_url, :api_version, :timeout, :max_retries

    # Default singleton client. Resources call into this; tests may swap it.
    def client
      @client ||= Client.new
    end

    # Reset the singleton (used in tests).
    def reset_client!
      @client = nil
    end
  end
end
