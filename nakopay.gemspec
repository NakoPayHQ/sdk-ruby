require_relative "lib/nakopay/version"

Gem::Specification.new do |s|
  s.name        = "nakopay"
  s.version     = NakoPay::VERSION
  s.summary     = "Official NakoPay SDK for Ruby."
  s.description = "Ruby client for the NakoPay crypto-payments API. Pinned to API version 2025-04-20."
  s.authors     = ["NakoPay"]
  s.email       = ["sdk@nakopay.com"]
  s.homepage    = "https://github.com/NakoPayHQ/sdk-ruby"
  s.license     = "MIT"
  s.required_ruby_version = ">= 3.0"

  s.files = Dir["lib/**/*.rb", "LICENSE", "README.md"]
  s.require_paths = ["lib"]

  s.metadata = {
    "homepage_uri"      => "https://nakopay.com",
    "source_code_uri"   => "https://github.com/NakoPayHQ/sdk-ruby",
    "documentation_uri" => "https://nakopay.com/docs/sdk/ruby",
    "changelog_uri"     => "https://github.com/NakoPayHQ/sdk-ruby/blob/main/CHANGELOG.md",
    "bug_tracker_uri"   => "https://github.com/NakoPayHQ/sdk-ruby/issues",
  }
end
