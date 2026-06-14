# frozen_string_literal: true

# Example: RSpec with confidence scoring (tans-parser 0.1.5+)
#
# Run with:
#   bundle exec rspec examples/rspec_confidence_example_spec.rb
#
require "tui_td"
require "tui_td/matchers"

RSpec.describe "Button detection with confidence" do
  before(:all) do
    # Generate terminal output with button-like patterns
    cmd = "printf '[ OK ] ( Cancel )\n\nReady.'"
    @driver = TUITD::Driver.new(cmd, rows: 5, cols: 30, timeout: 10)
    @driver.start
  end

  after(:all) do
    @driver&.close
  end

  it "detects OK button with high confidence" do
    expect(@driver).to have_button("OK", min_confidence: 0.8)
  end

  it "rejects OK button at very high threshold" do
    expect(@driver).not_to have_button("OK", min_confidence: 0.95)
  end

  it "detects Cancel button with good confidence" do
    expect(@driver).to have_button("Cancel", min_confidence: 0.8)
  end

  it "filters by role with confidence" do
    expect(@driver).to have_role(:button, text: "OK", min_confidence: 0.8)
  end
end
