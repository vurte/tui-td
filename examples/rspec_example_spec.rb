# frozen_string_literal: true

# Example: TUI test in RSpec
#
# Run with:
#   bundle exec rspec examples/rspec_example_spec.rb
#
require "tui_td"
require "tui_td/matchers"

RSpec.describe "Echo command" do
  before(:all) do
    @driver = TUITD::Driver.new("echo hello world", rows: 10, cols: 60, timeout: 10)
    @driver.start
    @driver.wait_for_stable
  end

  after(:all) do
    @driver&.close
  end

  let(:state) { TUITD::State.new(@driver.state_data) }

  it "shows the expected output" do
    expect(state).to have_text("hello world")
  end

  it "has default colors" do
    expect(state).to have_fg("default").at(0, 0)
    expect(state).to have_bg("default").at(0, 0)
  end

  it "has no bold text" do
    expect(state).to have_style.at(0, 0).with(bold: false)
  end
end
