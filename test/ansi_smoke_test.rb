#!/usr/bin/env ruby
# frozen_string_literal: true

# Smoke test: ANSI sequence handling in tui-td/tans-parser.
# Documents which ANSI sequences are correctly handled and which are not.
#
# Usage: ruby test/ansi_smoke_test.rb

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "minitest/autorun"
require "tui_td"
require "tui_td/minitest/assertions"

class ANSISmokeTest < Minitest::Test
  include TUITD::Minitest::Assertions

  # ── Standard sequences (should all pass) ──

  def test_cup_cursor_position_works
    # CUP: \e[row;colH uses 1-based coordinates
    # \e[5;10H moves to 1-based row 5, col 10 → 0-based row 4, col 9
    driver = TUITD::Driver.new(
      "printf '\e[5;10HWORKS'",
      rows: 10, cols: 20, timeout: 5,
    )
    driver.start
    state = driver.state
    # Row 4 (0-based) = 1-based row 5
    row4 = state[:rows][4].map { |c| c[:char] }.join
    assert_includes row4, "WORKS", "CUP should position to row 5 (1-based)"
  ensure
    driver&.close
  end

  def test_el_erase_line_works
    # EL: \e[K — erase from cursor to end of line
    driver = TUITD::Driver.new(
      "printf '\e[2;1Hall gone now\e[2;6H\e[K'",
      rows: 5, cols: 20, timeout: 5,
    )
    driver.start
    state = driver.state
    row1 = state[:rows][1].map { |c| c[:char] }.join
    # "all g" should remain (chars 0-4), rest erased
    assert_includes row1, "all g"
    refute_includes row1, "gone now"
  ensure
    driver&.close
  end

  def test_decsr_cursor_save_restore_works
    # DECSC/DECRC: \e7 / \e8 — save and restore cursor position
    driver = TUITD::Driver.new(
      "printf '\e[3;5HSAVED\e7\e[1;1Htemp\e8RESTORED'",
      rows: 10, cols: 20, timeout: 5,
    )
    driver.start
    state = driver.state
    # After restore, "RESTORED" should appear at row 2 (0-based)
    row2 = state[:rows][2].map { |c| c[:char] }.join
    assert_includes row2, "SAVED"
    assert_includes row2, "RESTORED"
    # "temp" should be at row 0
    row0 = state[:rows][0].map { |c| c[:char] }.join
    assert_includes row0, "temp"
  ensure
    driver&.close
  end

  # ── Unsupported sequences (documenting known gaps) ──

  def test_cha_cursor_horizontal_absolute_unsupported
    # CHA: \e[G — move cursor to column N on current row
    # KNOWN ISSUE: CHA is matched by tans-parser regex but not handled.
    # Cursor stays at wrong position → text lands in wrong column.
    # Ref: https://gitlab.com/haluk786/tans-parser/-/work_items/8
    skip "CHA not yet supported in tans-parser (tans-parser issue #8)"
    driver = TUITD::Driver.new(
      "printf '          Original\e[1GCHA_REPLACE'",
      rows: 3, cols: 30, timeout: 5,
    )
    driver.start
    state = driver.state
    row0 = state[:rows][0].map { |c| c[:char] }.join
    # Expected: CHA_REPLACE at column 0 (overwrites spaces)
    # Actual (unsupported): CHA_REPLACE appended after "Original"
    assert row0.start_with?("CHA_REPLACE"), "CHA should move to column 1"
  ensure
    driver&.close
  end

  # ── Realistic write_row simulation (the issue #9 scenario) ──

  def test_write_row_simulation_with_standard_sequences
    # Simulating write_row using only CUP + EL (both supported)
    # This pattern SHOULD work and is the baseline for issue #9
    driver = TUITD::Driver.new(
      "printf '\e[6;1Hwrite_row text here\e[K'",
      rows: 10, cols: 30, timeout: 5,
    )
    driver.start
    state = driver.state
    row5 = state[:rows][5].map { |c| c[:char] }.join
    assert_includes row5, "write_row text here"
  ensure
    driver&.close
  end

  def test_multi_write_row_simulation
    # Multi-row update using CUP + EL (simulating multi-row refresh)
    driver = TUITD::Driver.new(
      "printf '\e[2;1HLine two content\e[K\e[5;1HLine five content\e[K'",
      rows: 10, cols: 30, timeout: 5,
    )
    driver.start
    state = driver.state
    row1 = state[:rows][1].map { |c| c[:char] }.join
    row4 = state[:rows][4].map { |c| c[:char] }.join
    assert_includes row1, "Line two content"
    assert_includes row4, "Line five content"
  ensure
    driver&.close
  end

  # ── Timing / flush test (relevant to issue #9) ──

  def test_rapid_write_flush_sequence
    # Rapid write+flush updates should all be captured
    driver = TUITD::Driver.new(
      "ruby -e \"$stdout.sync=true; $stdout.write '\e[1;1HFirst'; $stdout.flush; " \
      "sleep 0.1; $stdout.write '\e[2;1HSecond'; $stdout.flush; " \
      "sleep 0.1; $stdout.write '\e[3;1HThird'; $stdout.flush; sleep 0.2\"",
      rows: 5, cols: 20, timeout: 5,
    )
    driver.start
    driver.wait_for_text("Third")
    assert_text(driver, "First")
    assert_text(driver, "Second")
    assert_text(driver, "Third")
  ensure
    driver&.close
  end

  def test_print_vs_write_identical_output
    # print with ANSI cursor vs write+flush with ANSI cursor — same bytes in PTY
    text_print = run_ansi_command("print '\e[1;1HLine1\e[K'; $stdout.flush", rows: 3, cols: 20)
    text_write = run_ansi_command("$stdout.write '\e[1;1HLine1\e[K'; $stdout.flush", rows: 3, cols: 20)
    assert text_print.include?("Line1")
    assert text_write.include?("Line1")
    assert_equal text_print.strip, text_write.strip
  end

  private

  # Helper: run a ruby -e command and return the first row's text content
  def run_ansi_command(code, rows:, cols:)
    driver = TUITD::Driver.new("ruby -e \"#{code}\"", rows: rows, cols: cols, timeout: 5)
    driver.start
    text = driver.state[:rows][0].map { |c| c[:char] }.join
    driver.close
    text
  end
end
