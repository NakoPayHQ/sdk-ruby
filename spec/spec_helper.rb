require "webmock/rspec"
require "nakopay"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.before do
    NakoPay.api_key = "sk_test_abc"
    NakoPay.base_url = "https://api.test.local/v1"
    NakoPay.max_retries = 1
    NakoPay.reset_client!
  end
  config.after { WebMock.reset! }
end
