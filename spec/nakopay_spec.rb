require "spec_helper"
require "openssl"
require "json"

RSpec.describe NakoPay do
  describe "client" do
    it "rejects publishable keys" do
      NakoPay.api_key = "pk_live_abc"
      NakoPay.reset_client!
      expect { NakoPay.client }.to raise_error(ArgumentError, /publishable key/)
    end
  end

  describe NakoPay::Invoice do
    it "creates an invoice and sends headers" do
      stub = stub_request(:post, "https://api.test.local/v1/invoices-create")
        .with(
          body: hash_including("amount" => "10.00"),
          headers: {
            "Authorization"     => "Bearer sk_test_abc",
            "X-NakoPay-Version" => "2025-04-20",
            "Content-Type"      => "application/json",
          },
        )
        .to_return(status: 200, body: { id: "inv_1", object: "invoice", amount: "10.00", checkout_url: "https://nakopay.com/pay/inv_1" }.to_json)

      inv = NakoPay::Invoice.create(amount: "10.00", currency: "USD", coin: "BTC", idempotency_key: "k1")
      expect(inv.id).to eq("inv_1")
      expect(inv.checkout_url).to include("inv_1")
      expect(stub).to have_been_requested
    end

    it "auto-generates an idempotency key when missing" do
      stub_request(:post, "https://api.test.local/v1/invoices-create")
        .with { |req| req.headers["Idempotency-Key"].to_s.start_with?("idem_") }
        .to_return(status: 200, body: { id: "inv_2" }.to_json)

      NakoPay::Invoice.create(amount: "1.00", currency: "USD", coin: "BTC")
    end

    it "raises APIError with envelope fields" do
      stub_request(:post, "https://api.test.local/v1/invoices-create")
        .to_return(
          status: 400,
          headers: { "X-Request-Id" => "req_xyz" },
          body: { error: { code: "validation_error", message: "amount required", param: "amount", type: "invalid_request_error" } }.to_json,
        )

      expect { NakoPay::Invoice.create(currency: "USD", coin: "BTC") }
        .to raise_error(NakoPay::APIError) { |e|
          expect(e.code).to eq("validation_error")
          expect(e.param).to eq("amount")
          expect(e.request_id).to eq("req_xyz")
          expect(e.status_code).to eq(400)
        }
    end

    it "retries on 429 then succeeds" do
      stub_request(:get, "https://api.test.local/v1/invoices-get?id=inv_3")
        .to_return({ status: 429, headers: { "Retry-After" => "0" }, body: '{"error":{"code":"rate_limited","message":"slow down"}}' },
                   { status: 200, body: '{"id":"inv_3","object":"invoice"}' })

      inv = NakoPay::Invoice.retrieve("inv_3")
      expect(inv.id).to eq("inv_3")
    end
  end

  describe NakoPay::Webhook do
    let(:secret)  { "whsec_test" }
    let(:body)    { '{"id":"evt_1","object":"event","type":"invoice.paid","api_version":"2025-04-20","created":1,"livemode":false,"data":{}}' }
    let(:ts)      { Time.now.to_i }
    let(:sig)     { "t=#{ts},v1=#{OpenSSL::HMAC.hexdigest("sha256", secret, "#{ts}.#{body}")}" }

    it "verifies a valid signature" do
      ev = described_class.construct_event(body, sig, secret)
      expect(ev["type"]).to eq("invoice.paid")
    end

    it "raises on tampered body" do
      expect { described_class.construct_event("{}", sig, secret) }
        .to raise_error(NakoPay::SignatureVerificationError) { |e| expect(e.code).to eq("signature_mismatch") }
    end

    it "raises on stale timestamp" do
      old = "t=1,v1=#{OpenSSL::HMAC.hexdigest("sha256", secret, "1.#{body}")}"
      expect { described_class.construct_event(body, old, secret) }
        .to raise_error(NakoPay::SignatureVerificationError) { |e| expect(e.code).to eq("signature_timestamp_outside_tolerance") }
    end

    it "raises when header is missing" do
      expect { described_class.construct_event(body, "", secret) }
        .to raise_error(NakoPay::SignatureVerificationError) { |e| expect(e.code).to eq("signature_missing") }
    end
  end

  describe NakoPay::Rate do
    it "joins quotes into a comma-separated query param" do
      stub_request(:get, "https://api.test.local/v1/rates-get?base=BTC&quotes=USD,EUR")
        .to_return(status: 200, body: { object: "rates", base: "BTC", quotes: { USD: "50000" } }.to_json)
      r = NakoPay::Rate.retrieve(base: "BTC", quotes: %w[USD EUR])
      expect(r.quotes["USD"]).to eq("50000")
    end
  end
end
