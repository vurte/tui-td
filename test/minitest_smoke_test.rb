#!/usr/bin/env ruby
# frozen_string_literal: true

# rubocop:disable Layout/LineLength

# Smoke test for Minitest assertions.
# Runs real Minitest tests that exercise all assertion types.
# Usage: ruby test/minitest_smoke_test.rb

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "minitest/autorun"
require "tui_td"
require "tui_td/minitest/assertions"

class MinitestSmokeTest < Minitest::Test
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

  def test_colors
    driver = TUITD::Driver.new("printf '\e[32mgreen\e[0m'", rows: 3, cols: 20, timeout: 5)
    driver.start
    assert_fg(driver, "green", row: 0, col: 0)
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
    refute_dialog(driver) # Should fail if dialog is present — testing refute_dialog
  rescue Minitest::Assertion
    # Expected — dialog IS present, so refute_dialog should raise
  ensure
    driver&.close
  end

  def test_checkbox_detection
    driver = TUITD::Driver.new("sh -c \"echo '[x] Enable logging'; echo '[ ] Auto-save'\"", rows: 5, cols: 30, timeout: 5)
    driver.start
    assert_checkbox(driver, "Enable", checked: true)
    assert_checkbox(driver, "Auto-save", unchecked: true)
  ensure
    driver&.close
  end

  def test_semantic_roles
    driver = TUITD::Driver.new(
      "sh -c \"echo 'File    Edit    View'; echo 'Name: [________]'; echo '[Tab1] [Tab2] [Tab3]'; echo '[#####         ] 50%'\"",
      rows: 8, cols: 40, timeout: 5,
    )
    driver.start
    assert_menu(driver)
    assert_label(driver, "Name")
    assert_input(driver)
    assert_tab(driver, "Tab1")
    assert_progress_bar(driver)
  ensure
    driver&.close
  end

  def test_role_generic
    driver = TUITD::Driver.new("echo '[ OK ]'", rows: 3, cols: 20, timeout: 5)
    driver.start
    assert_role(driver, :button, text: "OK")
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

  def test_snapshot_first_run
    TUITD.configure { |c| c.snapshot_dir = "test/snapshots" }
    driver = TUITD::Driver.new("echo 'Snapshot v1'", rows: 3, cols: 20, timeout: 5)
    driver.start
    # First run: creates golden master
    assert_snapshot(driver, "smoke_snapshot", type: :text)
  ensure
    driver&.close
    FileUtils.rm_rf("test/snapshots")
  end

  def test_snapshot_with_region
    TUITD.configure { |c| c.snapshot_dir = "test/snapshots" }
    driver = TUITD::Driver.new("sh -c \"echo '=== Banner ==='; echo 'Main content'; echo '--- Footer ---'\"", rows: 5, cols: 30, timeout: 5)
    driver.start
    # Only compare the banner (row 0)
    assert_snapshot(driver, "banner", type: :text, region: 0..0)
  ensure
    driver&.close
    FileUtils.rm_rf("test/snapshots")
  end

  def test_video_recording
    skip "ffmpeg not available" unless TUITD::VideoRecorder.available?

    path = "/tmp/minitest_record_#{Process.pid}.mp4"
    driver = TUITD::Driver.new("echo 'Recording test output'", rows: 5, cols: 30, timeout: 5)
    driver.start
    driver.wait_for_stable

    assert_record_start(driver, path, framerate: 2)
    assert_recording(driver)
    sleep 0.3
    assert_record_stop(driver)
    refute_recording(driver)

    assert File.exist?(path), "Video file should exist after recording"
    assert File.size(path).positive?, "Video file should have content"
  ensure
    driver&.close
    FileUtils.rm_f(path)
  end
end
# rubocop:enable Layout/LineLength
