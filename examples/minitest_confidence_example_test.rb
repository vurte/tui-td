# frozen_string_literal: true

# Example: Minitest with confidence scoring (tans-parser 0.1.5+)
#
# Run with:
#   bundle exec ruby examples/minitest_confidence_example_test.rb
#

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "tui_td"
require "tui_td/minitest/assertions"
require "minitest/autorun"

class ConfidenceTest < Minitest::Test
  include TUITD::Minitest::Assertions

  def setup
    @driver = TUITD::Driver.new("printf '[ OK ] ( Cancel )'", rows: 5, cols: 30, timeout: 10)
    @driver.start
  end

  def teardown
    @driver&.close
  end

  def test_button_with_high_confidence
    assert_button(@driver, "OK", min_confidence: 0.8)
  end

  def test_cancel_button_with_confidence
    # ( Cancel ) with parens has confidence 0.85
    assert_button(@driver, "Cancel", min_confidence: 0.8)
  end

  def test_role_with_confidence
    assert_role(@driver, :button, text: "Cancel", min_confidence: 0.8)
  end

end
