# nakopay (Ruby gem)

Official [NakoPay](https://nakopay.com) SDK for Ruby.

```bash
gem install nakopay
```

## Quick start

```ruby
require "nakopay"

NakoPay.api_key = ENV["NAKOPAY_SECRET_KEY"]

invoice = NakoPay::Invoice.create(
  amount:         "19.99",
  currency:       "USD",
  coin:           "BTC",
  description:    "Pro plan",
  customer_email: "alex@acme.com",
  idempotency_key: "ord_1042",
)

puts invoice.id, invoice.checkout_url
```

## Features

- Pinned to API version `2025-04-20`
- Auto-retry on `429` / `5xx` with exponential backoff + jitter
- Auto-generated `Idempotency-Key` for every POST
- Webhook signature verifier: `NakoPay::Webhook.construct_event(payload, sig_header, secret)`
- Typed errors: `NakoPay::APIError`, `NakoPay::SignatureVerificationError`

## Webhooks

```ruby
post "/webhook" do
  payload = request.body.read
  begin
    event = NakoPay::Webhook.construct_event(
      payload,
      request.env["HTTP_X_NAKOPAY_SIGNATURE"],
      ENV.fetch("NAKOPAY_WEBHOOK_SECRET"),
    )
  rescue NakoPay::SignatureVerificationError
    halt 400
  end

  fulfill(event["data"]["object"]) if event["type"] == "invoice.paid"
  status 200
end
```

## Links

- [NakoPay Website](https://nakopay.com)
- [Documentation](https://nakopay.com/docs)
- [Integration Guide](https://nakopay.com/docs/ruby)
- [API Reference](https://nakopay.com/docs/api-reference)

## License

MIT - see [LICENSE](./LICENSE).
