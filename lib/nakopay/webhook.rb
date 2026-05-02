require "openssl"
require "json"

module NakoPay
  # Webhook signature verifier.
  #
  #   NakoPay::Webhook.construct_event(raw_body, sig_header, secret)
  #
  # Header format:  t=<unix>,v1=<hex_hmac>
  # Signed payload: <t>.<raw_body>
  module Webhook
    DEFAULT_TOLERANCE = 300 # seconds

    module_function

    def construct_event(payload, sig_header, secret, tolerance: DEFAULT_TOLERANCE)
      raise SignatureVerificationError.new("missing X-NakoPay-Signature header", code: "signature_missing") if sig_header.nil? || sig_header.empty?
      raise SignatureVerificationError.new("webhook secret is required", code: "secret_missing") if secret.nil? || secret.empty?

      parts = sig_header.split(",").each_with_object({}) do |kv, h|
        k, v = kv.split("=", 2)
        h[k.strip] = v.to_s.strip if k && v
      end

      ts = Integer(parts["t"]) rescue nil
      v1 = parts["v1"]
      raise SignatureVerificationError.new("malformed signature header", code: "signature_invalid") if ts.nil? || v1.nil? || v1.empty?

      now = Time.now.to_i
      if (now - ts).abs > tolerance
        raise SignatureVerificationError.new("timestamp outside tolerance window", code: "signature_timestamp_outside_tolerance")
      end

      expected = OpenSSL::HMAC.hexdigest("sha256", secret, "#{ts}.#{payload}")
      unless secure_compare(expected, v1)
        raise SignatureVerificationError.new("signature does not match expected value", code: "signature_mismatch")
      end

      begin
        JSON.parse(payload)
      rescue JSON::ParserError
        raise SignatureVerificationError.new("webhook payload is not valid JSON", code: "payload_invalid_json")
      end
    end

    def secure_compare(a, b)
      return false unless a.bytesize == b.bytesize

      l = a.unpack("C*")
      res = 0
      b.each_byte { |byte| res |= byte ^ l.shift }
      res.zero?
    end
  end
end
