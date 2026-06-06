# frozen_string_literal: true

# Example: Snapshot Testing with RSpec
#
# Demonstrates named snapshots, region:, ignore_rows:, and types.
# Run with: bundle exec rspec examples/rspec_snapshot_spec.rb
# Update snapshots: UPDATE_SNAPSHOTS=1 bundle exec rspec examples/rspec_snapshot_spec.rb

require "tui_td"
require "tui_td/matchers"

RSpec.describe "Snapshot Testing Examples" do
  before(:all) do
    TUITD.configure { |c| c.snapshot_dir = "spec/snapshots" }
  end

  let(:command) { "sh -c \"echo '=== Banner ==='; echo 'Main content'; echo '--- Footer ---'\"" }
  let(:driver) { TUITD::Driver.new(command, rows: 5, cols: 30, timeout: 5) }

  after { driver&.close }

  it "creates and matches a named snapshot" do
    driver.start

    # First run: auto-creates the golden master
    expect(driver).to match_snapshot("hello_world")

    # Second run: compares against saved snapshot
    driver.close
    driver.start
    expect(driver).to match_snapshot("hello_world")
  end

  it "compares only a region of the screen" do
    driver.start

    # Only compare the banner (rows 0-0), ignore the rest
    expect(driver).to match_snapshot("banner_only", region: 0..0, chars_only: true)
  end

  it "ignores volatile rows" do
    driver.start

    # Footer changes between runs, skip it
    expect(driver).to match_snapshot("skip_footer", ignore_rows: [2])
  end

  it "compares using different types" do
    driver.start

    # Full comparison (chars + colors)
    expect(driver).to match_snapshot("full_state", type: :full)

    # Screenshot comparison
    expect(driver).to match_snapshot("screenshot", type: :png)
  end

  it "uses legacy in-memory snapshot" do
    driver.start
    pre = driver.snapshot

    # Do something that shouldn't change the screen
    driver.send("\n")

    # Compare against in-memory snapshot
    expect(driver).to match_snapshot(pre, chars_only: true)
  end
end
