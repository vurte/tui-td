# frozen_string_literal: true

require "spec_helper"

RSpec.describe TUITD do
  describe "VERSION" do
    it "is a valid semver string" do
      expect(TUITD::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end

    it "is a frozen string" do
      expect(TUITD::VERSION).to be_frozen
    end

    it "matches the gemspec version" do
      gemspec_path = File.expand_path("../tui-td.gemspec", __dir__)
      gemspec = File.read(gemspec_path)
      version_in_gemspec = gemspec.match(/spec\.version\s*=\s*TUITD::VERSION/)
      expect(version_in_gemspec).not_to be_nil
    end
  end
end
