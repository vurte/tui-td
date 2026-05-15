# frozen_string_literal: true

require_relative "lib/tui_td/version"

Gem::Specification.new do |spec|
  spec.name          = "tui-td"
  spec.version       = TUITD::VERSION
  spec.authors       = ["Haluk Durmus"]
  spec.email         = ["haluk_durmus@yahoo.de"]

  spec.summary       = "AI-friendly TUI (Terminal User Interface) testing framework"
  spec.description   = "tui-td is a Ruby framework for testing terminal UIs. " \
                       "It drives TUIs in a PTY, captures ANSI state (colors, layout, cursor), " \
                       "and outputs structured data that AI models can understand. " \
                       "Supports screenshot rendering for vision model consumption."
  spec.homepage      = "https://github.com/vurte/tui-td"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*.rb",
    "bin/*",
    "README.md",
    "LICENSE.txt",
    "CHANGELOG.md"
  ]
  spec.bindir = "bin"
  spec.executables = ["tui-td"]
  spec.require_paths = ["lib"]

  spec.add_dependency "io-console", "~> 0.7"
  spec.add_dependency "json", "~> 2.0"
  spec.add_dependency "stringio", "~> 3.0"
  spec.add_dependency "chunky_png", "~> 1.4"

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "pry", "~> 0.14"
  spec.add_development_dependency "rubocop", "~> 1.50"
end
