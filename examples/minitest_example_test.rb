# frozen_string_literal: true

# Example: TUI Testing with Minitest
#
# Run with: ruby -I lib -I test examples/minitest_example_test.rb

require "minitest/autorun"
require "tui_td"
require "tui_td/minitest/assertions"

class TUITest < Minitest::Test
  include TUITD::Minitest::Assertions

  def test_text_and_regex
    driver = TUITD::Driver.new("echo 'Hello World' && echo 'Status: OK'", rows: 5, cols: 30, timeout: 5)
    driver.start

    assert_text(driver, "Hello")
    assert_regex(driver, /Status: \w+/)
    refute_text(driver, "Error")
  ensure
    driver&.close
  end

  def test_button_detection
    driver = TUITD::Driver.new("echo '[ OK ]  (Cancel)  <Submit>'", rows: 3, cols: 40, timeout: 5)
    driver.start

    assert_button(driver, "OK")
    assert_button(driver, "Cancel")
    refute_button(driver, "Nonexistent")
  ensure
    driver&.close
  end

  def test_dialog_detection
    driver = TUITD::Driver.new("sh -c \"echo '┌── Dialog ──┐'; echo '│ [ OK ]    │'; echo '└───────────┘'\"", rows: 5, cols: 30, timeout: 5)
    driver.start

    assert_dialog(driver)
    assert_button(driver, "OK") # button inside dialog
  ensure
    driver&.close
  end

  def test_semantic_roles
    driver = TUITD::Driver.new(
      "sh -c \"echo 'File    Edit    View'; echo '[x] Enable logging'; echo '[ ] Auto-save'; echo 'Name: [________]'; echo '[Tab1] [Tab2]'\"",
      rows: 8, cols: 40, timeout: 5,
    )
    driver.start

    assert_menu(driver)
    assert_checkbox(driver, "Enable", checked: true)
    assert_checkbox(driver, "Auto-save", unchecked: true)
    assert_label(driver, "Name")
    assert_input(driver)
    assert_tab(driver, "Tab1")
  ensure
    driver&.close
  end

  def test_exit_status
    driver = TUITD::Driver.new("true", rows: 3, cols: 20, timeout: 5)
    driver.start
    driver.wait_for_exit

    assert_exit_status(driver, 0)
  ensure
    driver&.close
  end

  def test_named_snapshot
    driver = TUITD::Driver.new("echo 'Login Screen v1.0'", rows: 3, cols: 30, timeout: 5)
    driver.start

    # First run: creates golden master
    assert_snapshot(driver, "login_v1", type: :text)

    driver.close
    driver.start

    # Subsequent run: compares
    assert_snapshot(driver, "login_v1", type: :text)
  ensure
    driver&.close
  end

  def test_partial_snapshot_with_region
    driver = TUITD::Driver.new("sh -c \"echo '=== Banner ==='; echo 'Main content'; echo '--- Footer ---'\"", rows: 5, cols: 30, timeout: 5)
    driver.start

    # Only compare the banner (row 0)
    assert_snapshot(driver, "banner_region", type: :text, region: 0..0)
  ensure
    driver&.close
  end
end
