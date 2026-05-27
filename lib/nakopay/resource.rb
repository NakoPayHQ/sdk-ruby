module NakoPay
  # Lightweight wrapper that lets callers do `inv.id` instead of `inv["id"]`.
  class Resource
    def initialize(attrs)
      @attrs = attrs || {}
    end

    def [](key) = @attrs[key.to_s]
    def to_h = @attrs.dup
    def to_json(*) = @attrs.to_json

    def respond_to_missing?(name, include_private = false)
      @attrs.key?(name.to_s) || super
    end

    def method_missing(name, *args, &blk)
      key = name.to_s
      return @attrs[key] if @attrs.key?(key)

      super
    end
  end
end
