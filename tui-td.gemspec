# frozen_string_literal: true

require_relative "lib/tui_td/version"

Gem::Specification.new do |spec|
  spec.name          = "tui-td"
  spec.version       = TUITD::VERSION
  spec.authors       = ["Haluk Durmus"]
  spec.email         = ["haluk_durmus@yahoo.de"]

  spec.summary       = "TUI testing framework — RSpec, Minitest, JSON, and MCP"
  spec.description   = "tui-td drives terminal applications in a PTY, captures ANSI state " \
                       "as structured data, and provides PNG screenshots and HTML renders. " \
                       "Includes an MCP server for AI-driven testing, a JSON test runner, " \
                       "RSpec matchers, Minitest assertions, semantic selectors, and named " \
                       "snapshot testing."
  spec.homepage      = "https://github.com/vurte/tui-td"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*.rb",
    "bin/*",
    "README.md",
    "LICENSE.txt",
    "CHANGELOG.md",
  ]
  spec.bindir = "bin"
  spec.executables = ["tui-td"]
  spec.require_paths = ["lib"]

  spec.add_dependency "chunky_png", "~> 1.4"
  spec.add_dependency "io-console", "~> 0.7"
  spec.add_dependency "json", "~> 2.0"
  spec.add_dependency "stringio", "~> 3.0"
  spec.add_dependency "tans-parser", "~> 0.1.4"

  spec.add_development_dependency "bundler-audit", "~> 0.9"
  spec.add_development_dependency "minitest", "~> 5.15"
  spec.add_development_dependency "pry", "~> 0.14"
  spec.add_development_dependency "reek", "~> 6.3"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.50"
end
