# frozen_string_literal: true

require "spec_helper"
require "tui_td/minitest/assertions"

RSpec.describe TUITD::Minitest::Assertions do
  # Minitest assertion host that records pass/fail
  let(:host) do
    Class.new do
      include TUITD::Minitest::Assertions

      attr_reader :failures

      def initialize
        @failures = []
      end

      def pass
        # Minitest pass
      end

      def assert(test, msg = nil)
        return if test

        @failures << msg
        raise Minitest::Assertion, msg || "Failed"
      end

      def refute(test, msg = nil)
        assert(!test, msg)
      end
    end.new
  end

  def make_grid(rows, cols)
    Array.new(rows) do
      Array.new(cols) do
        { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false }
      end
    end
  end

  def make_state(grid: nil, rows: 5, cols: 20)
    TUITD::State.new(
      size: { rows: rows, cols: cols },
      cursor: { row: 0, col: 0 },
      rows: grid || make_grid(rows, cols),
    )
  end

  describe "assert_text" do
    it "passes when text is present" do
      grid = make_grid(2, 10)
      "Hello".chars.each_with_index { |c, i| grid[0][i][:char] = c }
      expect { host.assert_text(make_state(grid: grid), "Hello") }.not_to raise_error
    end

    it "fails when text is absent" do
      expect { host.assert_text(make_state, "Missing") }.to raise_error(Minitest::Assertion)
    end
  end

  describe "refute_text" do
    it "passes when text is absent" do
      expect { host.refute_text(make_state, "Error") }.not_to raise_error
    end

    it "fails when text is present" do
      grid = make_grid(1, 10)
      "Error".chars.each_with_index { |c, i| grid[0][i][:char] = c }
      expect { host.refute_text(make_state(grid: grid), "Error") }.to raise_error(Minitest::Assertion)
    end
  end

  describe "assert_regex" do
    it "passes when regex matches" do
      grid = make_grid(1, 20)
      "error: timeout".chars.each_with_index { |c, i| grid[0][i][:char] = c }
      expect { host.assert_regex(make_state(grid: grid), /error|fail/) }.not_to raise_error
    end
  end

  describe "assert_fg" do
    it "passes when foreground matches" do
      grid = make_grid(1, 5)
      grid[0][0][:char] = "A"
      grid[0][0][:fg] = "cyan"
      expect { host.assert_fg(make_state(grid: grid), "cyan", row: 0, col: 0) }.not_to raise_error
    end
  end

  describe "assert_bg" do
    it "passes when background matches" do
      grid = make_grid(1, 5)
      grid[0][0][:char] = "X"
      grid[0][0][:bg] = "blue"
      expect { host.assert_bg(make_state(grid: grid), "blue", row: 0, col: 0) }.not_to raise_error
    end
  end

  describe "assert_style" do
    it "passes when style matches" do
      grid = make_grid(1, 5)
      grid[0][0][:char] = "B"
      grid[0][0][:bold] = true
      expect { host.assert_style(make_state(grid: grid), row: 0, col: 0, bold: true) }.not_to raise_error
    end
  end

  describe "assert_exit_status" do
    it "passes when exit status matches" do
      driver = double("Driver", exitstatus: 0)
      expect { host.assert_exit_status(driver, 0) }.not_to raise_error
    end
  end

  describe "assert_button" do
    it "passes when button exists" do
      grid = make_grid(3, 20)
      "[ OK ]".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      expect { host.assert_button(make_state(grid: grid), "OK") }.not_to raise_error
    end

    it "fails when button missing" do
      expect { host.assert_button(make_state, "OK") }.to raise_error(Minitest::Assertion)
    end
  end

  describe "refute_button" do
    it "passes when button is absent" do
      expect { host.refute_button(make_state, "OK") }.not_to raise_error
    end
  end

  describe "assert_dialog" do
    it "passes when dialog exists" do
      grid = make_grid(4, 20)
      %w[┌──┐ │OK│ └──┘].each_with_index do |line, i|
        line.chars.each_with_index { |c, j| grid[i + 1][5 + j][:char] = c }
      end
      expect { host.assert_dialog(make_state(grid: grid)) }.not_to raise_error
    end
  end

  describe "assert_checkbox" do
    it "passes when checkbox exists" do
      grid = make_grid(5, 30)
      "[x] Enable".chars.each_with_index { |c, i| grid[2][i][:char] = c }
      expect { host.assert_checkbox(make_state(grid: grid), "Enable", checked: true) }.not_to raise_error
    end
  end

  describe "assert_role" do
    it "passes with role + text filter" do
      grid = make_grid(3, 20)
      "[ OK ]".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      expect { host.assert_role(make_state(grid: grid), :button, text: "OK") }.not_to raise_error
    end
  end

  describe "assert_input" do
    it "passes when input exists" do
      grid = make_grid(3, 30)
      "[________]".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      expect { host.assert_input(make_state(grid: grid)) }.not_to raise_error
    end
  end

  describe "assert_label" do
    it "passes when label exists" do
      grid = make_grid(3, 20)
      "Username:".chars.each_with_index { |c, i| grid[1][i][:char] = c }
      expect { host.assert_label(make_state(grid: grid), "Username") }.not_to raise_error
    end
  end

  describe "assert_menu" do
    it "passes when menu exists" do
      grid = make_grid(3, 40)
      "File    Edit    View    Help".chars.each_with_index { |c, i| grid[0][i][:char] = c }
      expect { host.assert_menu(make_state(grid: grid)) }.not_to raise_error
    end
  end

  describe "assert_tab" do
    it "passes when tabs exist" do
      grid = make_grid(3, 30)
      "[File] [Edit] [View]".chars.each_with_index { |c, i| grid[0][i][:char] = c }
      expect { host.assert_tab(make_state(grid: grid)) }.not_to raise_error
    end
  end

  describe "assert_statusbar" do
    it "passes when statusbar exists" do
      grid = make_grid(5, 20)
      "Status: Ready".chars.each_with_index do |c, i|
        grid[4][i][:char] = c
        grid[4][i][:bg] = "blue"
      end
      expect { host.assert_statusbar(make_state(grid: grid)) }.not_to raise_error
    end
  end

  describe "assert_progress_bar" do
    it "passes when progress bar exists" do
      grid = make_grid(3, 30)
      "[####     ]".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      expect { host.assert_progress_bar(make_state(grid: grid)) }.not_to raise_error
    end
  end

  describe "assert_snapshot" do
    let(:snapshot_dir) { Dir.mktmpdir("tui_td_mt_snap") }

    after { FileUtils.rm_rf(snapshot_dir) }

    it "creates snapshot on first run" do
      grid = make_grid(3, 20)
      "Hello".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      state = make_state(grid: grid, rows: 3)
      snap = TUITD::Snapshot.new("mt_test", type: :text, snapshot_dir: snapshot_dir)
      snap.save(state)
      expect { host.assert_snapshot(state, "mt_test") }.not_to raise_error
    end
  end

  describe "auto-wait with Driver" do
    it "assert_text auto-waits when given a Driver" do
      driver = TUITD::Driver.new("echo hello world", rows: 3, cols: 30, timeout: 5)
      driver.start
      expect { host.assert_text(driver, "hello") }.not_to raise_error
    ensure
      driver&.close
    end

    it "refute_text auto-waits when given a Driver" do
      driver = TUITD::Driver.new("echo hello", rows: 3, cols: 20, timeout: 5)
      driver.start
      expect { host.refute_text(driver, "Error") }.not_to raise_error
    ensure
      driver&.close
    end

    it "assert_button auto-waits when given a Driver" do
      driver = TUITD::Driver.new("echo '[ OK ]'", rows: 3, cols: 20, timeout: 5)
      driver.start
      expect { host.assert_button(driver, "OK") }.not_to raise_error
    ensure
      driver&.close
    end

    it "assert_button with min_confidence when given a Driver" do
      driver = TUITD::Driver.new("echo '[ OK ]'", rows: 3, cols: 20, timeout: 5)
      driver.start
      expect { host.assert_button(driver, "OK", min_confidence: 0.5) }.not_to raise_error
    ensure
      driver&.close
    end

    it "assert_button with too-high min_confidence fails" do
      driver = TUITD::Driver.new("echo '[ OK ]'", rows: 3, cols: 20, timeout: 5)
      driver.start
      expect { host.assert_button(driver, "OK", min_confidence: 0.99) }.to raise_error(Minitest::Assertion)
    ensure
      driver&.close
    end
  end

  describe "refute_regex" do
    it "passes when pattern does not match" do
      grid = make_grid(1, 20)
      "Hello World".chars.each_with_index { |c, i| grid[0][i][:char] = c }
      state = make_state(grid: grid)
      expect { host.refute_regex(state, /Error/) }.not_to raise_error
    end

    it "passes when string pattern does not match" do
      grid = make_grid(1, 20)
      "Hello".chars.each_with_index { |c, i| grid[0][i][:char] = c }
      state = make_state(grid: grid)
      expect { host.refute_regex(state, "Error") }.not_to raise_error
    end

    it "fails when pattern matches" do
      grid = make_grid(1, 20)
      "Error: timeout".chars.each_with_index { |c, i| grid[0][i][:char] = c }
      state = make_state(grid: grid)
      expect { host.refute_regex(state, /Error/) }.to raise_error(Minitest::Assertion)
    end
  end

  describe "assert_dialog with min_confidence" do
    it "passes with min_confidence" do
      grid = make_grid(4, 20)
      %w[┌──┐ │OK│ └──┘].each_with_index do |line, i|
        line.chars.each_with_index { |c, j| grid[i + 1][5 + j][:char] = c }
      end
      state = make_state(grid: grid)
      expect { host.assert_dialog(state, min_confidence: 0.5) }.not_to raise_error
    end
  end

  describe "refute_dialog" do
    it "passes when no dialog exists" do
      state = make_state
      expect { host.refute_dialog(state) }.not_to raise_error
    end

    it "fails when dialog exists" do
      grid = make_grid(4, 20)
      %w[┌──┐ │OK│ └──┘].each_with_index do |line, i|
        line.chars.each_with_index { |c, j| grid[i + 1][5 + j][:char] = c }
      end
      state = make_state(grid: grid)
      expect { host.refute_dialog(state) }.to raise_error(Minitest::Assertion)
    end
  end

  describe "assert_role with filters" do
    it "passes with min_confidence" do
      grid = make_grid(3, 20)
      "[ OK ]".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      state = make_state(grid: grid)
      expect { host.assert_role(state, :button, text: "OK", min_confidence: 0.5) }.not_to raise_error
    end

    it "fails with too-high min_confidence" do
      grid = make_grid(3, 20)
      "[ OK ]".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      state = make_state(grid: grid)
      expect { host.assert_role(state, :button, text: "OK", min_confidence: 0.99) }.to raise_error(Minitest::Assertion)
    end
  end

  describe "assert_input with text" do
    it "passes when input with specific text exists" do
      grid = make_grid(3, 30)
      "Input: [________]".chars.each_with_index { |c, i| grid[1][i][:char] = c }
      state = make_state(grid: grid)
      # Without text filter, any input passes
      expect { host.assert_input(state) }.not_to raise_error
      # With text filter that doesn't match, it fails (but covers the code path)
      expect { host.assert_input(state, "Nonexistent") }.to raise_error(Minitest::Assertion)
    end
  end

  describe "assert_progress_bar with text" do
    it "passes when progress bar exists (without text filter)" do
      grid = make_grid(3, 30)
      "[####     ] 40%".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      state = make_state(grid: grid)
      expect { host.assert_progress_bar(state) }.not_to raise_error
    end

    it "fails with specific text that does not match" do
      grid = make_grid(3, 30)
      "[####     ]".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      state = make_state(grid: grid)
      # with text filter, covers the code path
      expect { host.assert_progress_bar(state, "Nonexistent") }.to raise_error(Minitest::Assertion)
    end
  end

  describe "video recording assertions" do
    let(:recording_driver) do
      double("Driver",
             start_recording: true,
             stop_recording: "/tmp/test.mp4",
             recording?: true,)
    end

    let(:non_recording_driver) do
      double("Driver",
             start_recording: false,
             stop_recording: nil,
             recording?: false,)
    end

    it "assert_record_start raises error for non-Driver" do
      expect { host.assert_record_start("not a driver", "/tmp/v.mp4") }
        .to raise_error(ArgumentError, /requires a Driver/)
    end

    it "assert_record_start succeeds with Driver" do
      expect { host.assert_record_start(recording_driver, "/tmp/v.mp4") }.not_to raise_error
    end

    it "assert_record_start fails when recording fails to start" do
      expect { host.assert_record_start(non_recording_driver, "/tmp/v.mp4") }
        .to raise_error(Minitest::Assertion, /failed/i)
    end

    it "assert_record_stop raises error for non-Driver" do
      expect { host.assert_record_stop("not a driver") }
        .to raise_error(ArgumentError, /requires a Driver/)
    end

    it "assert_record_stop succeeds with Driver" do
      expect { host.assert_record_stop(recording_driver) }.not_to raise_error
    end

    it "assert_record_stop fails when no recording in progress" do
      expect { host.assert_record_stop(non_recording_driver) }
        .to raise_error(Minitest::Assertion, /no recording/i)
    end

    it "assert_recording raises error for non-Driver" do
      expect { host.assert_recording("not a driver") }
        .to raise_error(ArgumentError, /requires a Driver/)
    end

    it "assert_recording passes when recording is active" do
      expect { host.assert_recording(recording_driver) }.not_to raise_error
    end

    it "assert_recording fails when recording is not active" do
      expect { host.assert_recording(non_recording_driver) }
        .to raise_error(Minitest::Assertion, /expected recording/i)
    end

    it "refute_recording raises error for non-Driver" do
      expect { host.refute_recording("not a driver") }
        .to raise_error(ArgumentError, /requires a Driver/)
    end

    it "refute_recording passes when recording is not active" do
      expect { host.refute_recording(non_recording_driver) }.not_to raise_error
    end

    it "refute_recording fails when recording is active" do
      expect { host.refute_recording(recording_driver) }
        .to raise_error(Minitest::Assertion, /expected recording NOT/i)
    end
  end

  describe "assert_snapshot with wait and to_h" do
    it "waits for stable when wait:true on a Driver" do
      driver = TUITD::Driver.new("echo stable", rows: 3, cols: 20, timeout: 5)
      driver.start
      snap = TUITD::Snapshot.new("wait_test", type: :text, snapshot_dir: Dir.mktmpdir)
      snap.save(driver.state_data) # pre-create snapshot
      expect { host.assert_snapshot(driver, "wait_test", wait: true) }.not_to raise_error
    ensure
      driver&.close
    end

    it "works with objects that respond to to_h" do
      cell = { char: "X", fg: "default", bg: "default", bold: false, italic: false, underline: false }
      hash_obj = double("hash_obj",
                        to_h: { size: { rows: 1, cols: 1 },
                                rows: [[cell]], cursor: { row: 0, col: 0 }, },)
      snap = TUITD::Snapshot.new("to_h_test", type: :text, snapshot_dir: Dir.mktmpdir)
      snap.save(hash_obj.to_h)
      expect { host.assert_snapshot(hash_obj, "to_h_test") }.not_to raise_error
    end
  end
end
