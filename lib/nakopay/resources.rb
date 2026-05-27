module NakoPay
  module Invoice
    module_function

    def create(idempotency_key: nil, **params)
      Resource.new(NakoPay.client.request(:post, "/invoices-create", body: params, idempotency_key: idempotency_key))
    end

    def retrieve(id)
      Resource.new(NakoPay.client.request(:get, "/invoices-get", query: { id: id }))
    end

    def list(limit: nil, starting_after: nil, status: nil)
      page = NakoPay.client.request(:get, "/invoices-list", query: { limit: limit, starting_after: starting_after, status: status })
      page["data"] = (page["data"] || []).map { |r| Resource.new(r) }
      page
    end

    def cancel(id, idempotency_key: nil)
      Resource.new(NakoPay.client.request(:post, "/invoices-cancel", body: { id: id }, idempotency_key: idempotency_key))
    end

    def auto_paging_each(limit: nil, status: nil)
      return enum_for(:auto_paging_each, limit: limit, status: status) unless block_given?

      cursor = nil
      loop do
        page = list(limit: limit, starting_after: cursor, status: status)
        page["data"].each { |inv| yield inv }
        break unless page["has_more"]

        cursor = page["next_cursor"] || page["data"].last&.id
        break unless cursor
      end
    end
  end

  module Customer
    module_function

    def create(idempotency_key: nil, **params)
      Resource.new(NakoPay.client.request(:post, "/customers", body: params, idempotency_key: idempotency_key))
    end

    def retrieve(id)
      Resource.new(NakoPay.client.request(:get, "/customers", query: { id: id }))
    end

    def list(limit: nil, starting_after: nil)
      page = NakoPay.client.request(:get, "/customers", query: { limit: limit, starting_after: starting_after })
      page["data"] = (page["data"] || []).map { |r| Resource.new(r) }
      page
    end
  end

  module PaymentLink
    module_function

    def create(idempotency_key: nil, **params)
      Resource.new(NakoPay.client.request(:post, "/payment-links", body: params, idempotency_key: idempotency_key))
    end

    def retrieve(id)
      Resource.new(NakoPay.client.request(:get, "/payment-links", query: { id: id }))
    end
  end

  module WebhookEndpoint
    module_function

    def create(idempotency_key: nil, **params)
      Resource.new(NakoPay.client.request(:post, "/webhooks-create", body: params, idempotency_key: idempotency_key))
    end

    def delete(id, idempotency_key: nil)
      NakoPay.client.request(:post, "/webhooks-delete", body: { id: id }, idempotency_key: idempotency_key)
    end

    def test(id, idempotency_key: nil)
      NakoPay.client.request(:post, "/webhooks-test", body: { id: id }, idempotency_key: idempotency_key)
    end

    def replay(id, delivery_id: nil, idempotency_key: nil)
      body = { id: id }
      body[:delivery_id] = delivery_id if delivery_id
      Resource.new(NakoPay.client.request(:post, "/webhooks-replay", body: body, idempotency_key: idempotency_key))
    end
  end

  module Logs
    module_function

    def list(limit: nil, starting_after: nil, **params)
      page = NakoPay.client.request(:get, "/logs-list", query: { limit: limit, starting_after: starting_after, **params })
      page["data"] = (page["data"] || []).map { |r| Resource.new(r) }
      page
    end
  end

  module Sandbox
    module_function

    # Seed the sandbox with demo customers + invoices. Test-mode key only.
    def seed(idempotency_key: nil, **params)
      Resource.new(NakoPay.client.request(:post, "/sandbox-seed", body: params, idempotency_key: idempotency_key))
    end
  end

  module Event
    module_function

    def list(limit: nil, starting_after: nil, type: nil)
      page = NakoPay.client.request(:get, "/events-list", query: { limit: limit, starting_after: starting_after, type: type })
      page["data"] = (page["data"] || []).map { |r| Resource.new(r) }
      page
    end

    def auto_paging_each(limit: nil, type: nil)
      return enum_for(:auto_paging_each, limit: limit, type: type) unless block_given?

      cursor = nil
      loop do
        page = list(limit: limit, starting_after: cursor, type: type)
        page["data"].each { |e| yield e }
        break unless page["has_more"]

        cursor = page["next_cursor"] || page["data"].last&.id
        break unless cursor
      end
    end
  end

  module Rate
    module_function

    def retrieve(base: nil, quotes: nil)
      q = { base: base }
      q[:quotes] = quotes.join(",") if quotes && !quotes.empty?
      Resource.new(NakoPay.client.request(:get, "/rates-get", query: q))
    end
  end

  module Credit
    module_function

    def balance
      Resource.new(NakoPay.client.request(:get, "/credits-balance"))
    end

    module Topup
      module_function

      def create(amount_sats:, idempotency_key: nil)
        Resource.new(NakoPay.client.request(:post, "/credits-topup-create", body: { amount_sats: amount_sats }, idempotency_key: idempotency_key))
      end

      def retrieve(id)
        Resource.new(NakoPay.client.request(:get, "/credits-topup-status", query: { id: id }))
      end
    end
  end

  module Subscription
    module_function

    def retrieve(id)
      Resource.new(NakoPay.client.request(:get, "/subscriptions-list", query: { id: id }))
    end

    def list(limit: nil, starting_after: nil, status: nil)
      page = NakoPay.client.request(:get, "/subscriptions-list", query: { limit: limit, starting_after: starting_after, status: status })
      page["data"] = (page["data"] || []).map { |r| Resource.new(r) }
      page
    end

    def cancel(id, at_period_end: true, idempotency_key: nil)
      Resource.new(NakoPay.client.request(:post, "/subscriptions-cancel", body: { subscription_id: id, at_period_end: at_period_end }, idempotency_key: idempotency_key))
    end

    def pause(id, token: nil, idempotency_key: nil)
      body = { subscription_id: id }
      body[:token] = token if token
      Resource.new(NakoPay.client.request(:post, "/subscriptions-pause", body: body, idempotency_key: idempotency_key))
    end

    def resume(id, token: nil, idempotency_key: nil)
      body = { subscription_id: id }
      body[:token] = token if token
      Resource.new(NakoPay.client.request(:post, "/subscriptions-resume", body: body, idempotency_key: idempotency_key))
    end

    def portal(id, idempotency_key: nil)
      Resource.new(NakoPay.client.request(:post, "/subscriptions-portal", body: { subscription_id: id }, idempotency_key: idempotency_key))
    end

    def auto_paging_each(limit: nil, status: nil)
      return enum_for(:auto_paging_each, limit: limit, status: status) unless block_given?

      cursor = nil
      loop do
        page = list(limit: limit, starting_after: cursor, status: status)
        page["data"].each { |s| yield s }
        break unless page["has_more"]

        cursor = page["next_cursor"] || page["data"].last&.id
        break unless cursor
      end
    end
  end

  module SubscriptionPlan
    module_function

    def list(limit: nil, starting_after: nil)
      page = NakoPay.client.request(:get, "/subscription-plans-list", query: { limit: limit, starting_after: starting_after })
      page["data"] = (page["data"] || []).map { |r| Resource.new(r) }
      page
    end
  end

  module Refund
    module_function

    def create(invoice_id:, idempotency_key: nil, **params)
      Resource.new(NakoPay.client.request(:post, "/refunds-create", body: { invoice_id: invoice_id, **params }, idempotency_key: idempotency_key))
    end

    def retrieve(id)
      Resource.new(NakoPay.client.request(:get, "/refunds-get", query: { id: id }))
    end

    def list(limit: nil, starting_after: nil, invoice_id: nil, status: nil)
      page = NakoPay.client.request(:get, "/refunds-list", query: { limit: limit, starting_after: starting_after, invoice_id: invoice_id, status: status })
      page["data"] = (page["data"] || []).map { |r| Resource.new(r) }
      page
    end

    def cancel(id, idempotency_key: nil)
      Resource.new(NakoPay.client.request(:post, "/refunds-cancel", body: { id: id }, idempotency_key: idempotency_key))
    end
  end

  module Key
    module_function

    def create(idempotency_key: nil, **params)
      Resource.new(NakoPay.client.request(:post, "/keys-create", body: params, idempotency_key: idempotency_key))
    end

    def list
      page = NakoPay.client.request(:get, "/keys-list")
      page["data"] = (page["data"] || []).map { |r| Resource.new(r) }
      page
    end

    def revoke(id, idempotency_key: nil)
      NakoPay.client.request(:post, "/keys-revoke", body: { id: id }, idempotency_key: idempotency_key)
    end

    def rotate(id, idempotency_key: nil)
      Resource.new(NakoPay.client.request(:post, "/keys-rotate", body: { id: id }, idempotency_key: idempotency_key))
    end
  end
end
