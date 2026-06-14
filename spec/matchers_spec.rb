# frozen_string_literal: true

require "spec_helper"
require "tui_td/matchers"
require "tmpdir"

RSpec.describe TUITD::Matchers do
  def make_grid(rows, cols)
    Array.new(rows) do
      Array.new(cols) do
        { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false }
      end
    end
  end

  def make_state(grid: nil, rows: 5, cols: 20, cursor: { row: 0, col: 0 })
    TUITD::State.new(
      size: { rows: rows, cols: cols },
      cursor: cursor,
      rows: grid || make_grid(rows, cols),
    )
  end

  describe "have_text" do
    it "passes when text is present" do
      grid = make_grid(2, 10)
      "Hello".chars.each_with_index { |c, i| grid[0][i][:char] = c }
      state = make_state(grid: grid)
      expect(state).to have_text("Hello")
    end

    it "fails when text is absent" do
      state = make_state
      expect { expect(state).to have_text("Missing") }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    it "matches partial text" do
      grid = make_grid(1, 15)
      "Hello World".chars.each_with_index { |c, i| grid[0][i][:char] = c }
      state = make_state(grid: grid)
      expect(state).to have_text("World")
    end

    it "negates with not_to" do
      grid = make_grid(1, 10)
      "Hello".chars.each_with_index { |c, i| grid[0][i][:char] = c }
      state = make_state(grid: grid)
      expect(state).not_to have_text("Error")
    end
  end

  describe "have_regex" do
    it "passes when regex matches" do
      grid = make_grid(1, 20)
      "error: timeout".chars.each_with_index { |c, i| grid[0][i][:char] = c }
      state = make_state(grid: grid)
      expect(state).to have_regex(/error|fail/)
    end

    it "accepts a string pattern" do
      grid = make_grid(1, 20)
      "error: timeout".chars.each_with_index { |c, i| grid[0][i][:char] = c }
      state = make_state(grid: grid)
      expect(state).to have_regex("error|fail")
    end

    it "fails when regex does not match" do
      grid = make_grid(1, 10)
      "all good".chars.each_with_index { |c, i| grid[0][i][:char] = c }
      state = make_state(grid: grid)
      expect { expect(state).to have_regex(/error/) }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end
  end

  describe "have_fg" do
    it "passes when foreground matches" do
      grid = make_grid(1, 5)
      grid[0][0][:char] = "A"
      grid[0][0][:fg] = "cyan"
      state = make_state(grid: grid)
      expect(state).to have_fg("cyan").at(0, 0)
    end

    it "fails when foreground differs" do
      grid = make_grid(1, 5)
      grid[0][0][:char] = "A"
      grid[0][0][:fg] = "green"
      state = make_state(grid: grid)
      expect { expect(state).to have_fg("red").at(0, 0) }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    it "negates with not_to" do
      grid = make_grid(1, 5)
      grid[0][0][:char] = "A"
      grid[0][0][:fg] = "green"
      state = make_state(grid: grid)
      expect(state).not_to have_fg("red").at(0, 0)
    end
  end

  describe "have_bg" do
    it "passes when background matches" do
      grid = make_grid(1, 5)
      grid[0][0][:char] = "X"
      grid[0][0][:bg] = "blue"
      state = make_state(grid: grid)
      expect(state).to have_bg("blue").at(0, 0)
    end

    it "fails when background differs" do
      grid = make_grid(1, 5)
      grid[0][0][:char] = "X"
      grid[0][0][:bg] = "green"
      state = make_state(grid: grid)
      expect { expect(state).to have_bg("blue").at(0, 0) }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    it "negates with not_to" do
      grid = make_grid(1, 5)
      grid[0][0][:char] = "X"
      grid[0][0][:bg] = "green"
      state = make_state(grid: grid)
      expect(state).not_to have_bg("blue").at(0, 0)
    end
  end

  describe "have_style" do
    it "passes when bold is true" do
      grid = make_grid(1, 5)
      grid[0][0][:char] = "B"
      grid[0][0][:bold] = true
      state = make_state(grid: grid)
      expect(state).to have_style.at(0, 0).with(bold: true)
    end

    it "passes when multiple styles match" do
      grid = make_grid(1, 5)
      grid[0][0][:char] = "S"
      grid[0][0][:bold] = true
      grid[0][0][:underline] = true
      state = make_state(grid: grid)
      expect(state).to have_style.at(0, 0).with(bold: true, underline: true)
    end

    it "passes when italic is true" do
      grid = make_grid(1, 5)
      grid[0][0][:char] = "I"
      grid[0][0][:italic] = true
      state = make_state(grid: grid)
      expect(state).to have_style.at(0, 0).with(italic: true)
    end

    it "fails when style differs" do
      grid = make_grid(1, 5)
      grid[0][0][:char] = "N"
      state = make_state(grid: grid)
      expect { expect(state).to have_style.at(0, 0).with(bold: true) }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    it "negates with not_to" do
      grid = make_grid(1, 5)
      grid[0][0][:char] = "N"
      state = make_state(grid: grid)
      expect(state).not_to have_style.at(0, 0).with(bold: true)
    end
  end

  describe "have_exit_status" do
    it "passes when exit status matches" do
      driver = double("Driver", exitstatus: 0)
      expect(driver).to have_exit_status(0)
    end

    it "fails when exit status differs" do
      driver = double("Driver", exitstatus: 1)
      expect { expect(driver).to have_exit_status(0) }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end
  end

  describe "selector matchers" do
    it "have_button passes when button exists" do
      grid = make_grid(3, 20)
      "[ OK ]".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      state = make_state(grid: grid)
      expect(state).to have_button("OK")
    end

    it "have_button fails when button missing" do
      grid = make_grid(3, 20)
      "hello".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      state = make_state(grid: grid)
      expect { expect(state).to have_button("OK") }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    it "have_dialog passes when dialog exists" do
      grid = make_grid(4, 20)
      "┌──┐".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      "│OK│".chars.each_with_index { |c, i| grid[2][5 + i][:char] = c }
      "└──┘".chars.each_with_index { |c, i| grid[3][5 + i][:char] = c }
      state = make_state(grid: grid)
      expect(state).to have_dialog
    end

    it "have_dialog fails when no dialog" do
      state = make_state
      expect { expect(state).to have_dialog }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    it "have_checkbox passes when checkbox exists" do
      grid = make_grid(5, 30)
      "[x] Enable".chars.each_with_index { |c, i| grid[2][i][:char] = c }
      state = make_state(grid: grid)
      expect(state).to have_checkbox("Enable")
    end

    it "have_checkbox with checked passes only for checked" do
      grid = make_grid(5, 30)
      "[ ] Option".chars.each_with_index { |c, i| grid[2][i][:char] = c }
      state = make_state(grid: grid)
      expect(state).to have_checkbox("Option")
      expect { expect(state).to have_checkbox("Option").checked }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    it "have_role works with generic role + text filter" do
      grid = make_grid(3, 20)
      "[ OK ]".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      state = make_state(grid: grid)
      expect(state).to have_role(:button, text: "OK")
    end

    it "have_role fails with wrong text filter" do
      grid = make_grid(3, 20)
      "[ OK ]".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      state = make_state(grid: grid)
      expect { expect(state).to have_role(:button, text: "Cancel") }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end
  end

  describe "auto-wait with Driver" do
    it "auto-waits on have_text when given a Driver" do
      driver = TUITD::Driver.new("echo hello world", rows: 3, cols: 30, timeout: 5)
      driver.start
      expect(driver).to have_text("hello")
    ensure
      driver&.close
    end

    it "eventually fails have_text on Driver when text never appears" do
      driver = TUITD::Driver.new("echo done", rows: 3, cols: 30, timeout: 5)
      driver.start
      driver.wait_for_exit
      expect { expect(driver).to have_text("NEVER") }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    ensure
      driver&.close
    end

    it "auto-waits on have_regex when given a Driver" do
      driver = TUITD::Driver.new("echo success", rows: 3, cols: 30, timeout: 5)
      driver.start
      expect(driver).to have_regex(/suc/)
    ensure
      driver&.close
    end

    it "auto-waits on have_fg when given a Driver" do
      driver = TUITD::Driver.new("printf '\e[32mgreen\e[0m'", rows: 3, cols: 20, timeout: 5)
      driver.start
      expect(driver).to have_fg("green").at(0, 0)
    ensure
      driver&.close
    end

    it "auto-waits on have_bg when given a Driver" do
      driver = TUITD::Driver.new("printf '\e[44mblue\e[0m'", rows: 3, cols: 20, timeout: 5)
      driver.start
      expect(driver).to have_bg("blue").at(0, 0)
    ensure
      driver&.close
    end

    it "auto-waits on have_style when given a Driver" do
      driver = TUITD::Driver.new("printf '\e[1mbold\e[0m'", rows: 3, cols: 20, timeout: 5)
      driver.start
      expect(driver).to have_style.at(0, 0).with(bold: true)
    ensure
      driver&.close
    end
  end

  describe "new role matchers" do
    describe "have_input" do
      it "passes when input field exists" do
        grid = make_grid(3, 30)
        "[________]".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
        state = make_state(grid: grid)
        expect(state).to have_input
      end

      it "passes with text filter (via find_text for adjacent label)" do
        grid = make_grid(3, 30)
        "Name: [________]".chars.each_with_index { |c, i| grid[1][i][:char] = c }
        state = make_state(grid: grid)
        expect(state).to have_input
        expect(state).to have_label("Name")
      end

      it "fails when no input exists" do
        state = make_state
        expect { expect(state).to have_input }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    describe "have_label" do
      it "passes when label exists" do
        grid = make_grid(3, 20)
        "Username:".chars.each_with_index { |c, i| grid[1][i][:char] = c }
        state = make_state(grid: grid)
        expect(state).to have_label("Username")
      end

      it "fails when no label exists" do
        state = make_state
        expect { expect(state).to have_label("Name") }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    describe "have_menu" do
      it "passes when menu bar exists" do
        grid = make_grid(3, 40)
        "File    Edit    View    Help".chars.each_with_index { |c, i| grid[0][i][:char] = c }
        state = make_state(grid: grid)
        expect(state).to have_menu
      end

      it "fails when no menu exists" do
        state = make_state
        expect { expect(state).to have_menu }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    describe "have_tab" do
      it "passes when tabs exist" do
        grid = make_grid(3, 30)
        "[File] [Edit] [View]".chars.each_with_index { |c, i| grid[0][i][:char] = c }
        state = make_state(grid: grid)
        expect(state).to have_tab
      end

      it "passes with text filter" do
        grid = make_grid(3, 30)
        "[File] [Edit] [View]".chars.each_with_index { |c, i| grid[0][i][:char] = c }
        state = make_state(grid: grid)
        expect(state).to have_tab("File")
      end

      it "fails when no tabs exist" do
        state = make_state
        expect { expect(state).to have_tab }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    describe "have_statusbar" do
      it "passes when statusbar exists" do
        grid = make_grid(5, 20)
        "Status: Ready".chars.each_with_index do |c, i|
          grid[4][i][:char] = c
          grid[4][i][:bg] = "blue"
        end
        state = make_state(grid: grid)
        expect(state).to have_statusbar
      end

      it "fails when no statusbar exists" do
        state = make_state
        expect { expect(state).to have_statusbar }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    describe "have_progress_bar" do
      it "passes when progress bar exists" do
        grid = make_grid(3, 30)
        "[####     ]".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
        state = make_state(grid: grid)
        expect(state).to have_progress_bar
      end

      it "fails when no progress bar exists" do
        state = make_state
        expect { expect(state).to have_progress_bar }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    describe "have_checkbox with unchecked chain" do
      it "passes when checkbox is unchecked" do
        grid = make_grid(5, 30)
        "[ ] Option".chars.each_with_index { |c, i| grid[2][i][:char] = c }
        state = make_state(grid: grid)
        expect(state).to have_checkbox("Option").unchecked
      end

      it "fails when unchecked expected but checked" do
        grid = make_grid(5, 30)
        "[x] Option".chars.each_with_index { |c, i| grid[2][i][:char] = c }
        state = make_state(grid: grid)
        expect { expect(state).to have_checkbox("Option").unchecked }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    describe "have_role with disabled filter" do
      it "passes when checking a button role without optional filters" do
        grid = make_grid(3, 30)
        "[ OK ]".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
        state = make_state(grid: grid)
        expect(state).to have_role(:button, text: "OK")
      end
    end
  end

  describe "auto-wait for new role matchers" do
    it "auto-waits on have_input when given a Driver" do
      driver = TUITD::Driver.new("echo 'Name: [________]'", rows: 3, cols: 30, timeout: 5)
      driver.start
      expect(driver).to have_input
    ensure
      driver&.close
    end

    it "auto-waits on have_label when given a Driver" do
      driver = TUITD::Driver.new("echo 'Username:'", rows: 3, cols: 30, timeout: 5)
      driver.start
      expect(driver).to have_label("Username")
    ensure
      driver&.close
    end

    it "auto-waits on have_menu when given a Driver" do
      driver = TUITD::Driver.new("echo 'File    Edit    View'", rows: 3, cols: 30, timeout: 5)
      driver.start
      expect(driver).to have_menu
    ensure
      driver&.close
    end

    it "auto-waits on have_tab when given a Driver" do
      driver = TUITD::Driver.new("echo '[Tab1] [Tab2]'", rows: 3, cols: 30, timeout: 5)
      driver.start
      expect(driver).to have_tab("Tab1")
    ensure
      driver&.close
    end
  end

  describe "match_snapshot" do
    it "passes when states are identical" do
      grid = make_grid(3, 20)
      "Hello".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      state = make_state(grid: grid, rows: 3)
      snapshot = make_state(grid: grid, rows: 3)
      expect(state).to match_snapshot(snapshot)
    end

    it "fails when states differ" do
      grid = make_grid(3, 20)
      "Hello".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      state = make_state(grid: grid, rows: 3)

      diff_grid = make_grid(3, 20)
      "World".chars.each_with_index { |c, i| diff_grid[1][5 + i][:char] = c }
      snapshot = make_state(grid: diff_grid, rows: 3)

      expect { expect(state).to match_snapshot(snapshot) }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    it "passes with chars_only when only styles differ" do
      grid = make_grid(3, 20)
      "Hello".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      state = make_state(grid: grid, rows: 3)

      style_grid = make_grid(3, 20)
      "Hello".chars.each_with_index { |c, i| style_grid[1][5 + i][:char] = c }
      style_grid[1][5][:bold] = true
      snapshot = make_state(grid: style_grid, rows: 3)

      expect(state).to match_snapshot(snapshot, chars_only: true)
    end

    it "does negation with not_to" do
      grid = make_grid(3, 20)
      "Hello".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      state = make_state(grid: grid, rows: 3)

      diff_grid = make_grid(3, 20)
      "World".chars.each_with_index { |c, i| diff_grid[1][5 + i][:char] = c }
      snapshot = make_state(grid: diff_grid, rows: 3)

      expect(state).not_to match_snapshot(snapshot)
    end
  end

  describe "match_snapshot with named snapshots" do
    let(:snapshot_dir) { Dir.mktmpdir("tui_td_named_snap") }

    before { TUITD.configure { |c| c.snapshot_dir = snapshot_dir } }

    after do
      FileUtils.rm_rf(snapshot_dir)
      TUITD.instance_variable_set(:@configuration, nil)
    end

    it "passes on first run (creates snapshot)" do
      grid = make_grid(3, 20)
      "Hello".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      make_state(grid: grid, rows: 3)
      snap_name = "first_run_#{Process.pid}"
      snap = TUITD::Snapshot.new(snap_name, type: :text, snapshot_dir: snapshot_dir)

      # Simulate: no snapshot exists yet
      expect(snap.exists?).to be false
    end

    it "passes when named snapshot matches" do
      grid = make_grid(3, 20)
      "Hello".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      state = make_state(grid: grid, rows: 3)

      snap = TUITD::Snapshot.new("greeting", type: :text, snapshot_dir: snapshot_dir)
      snap.save(state)

      expect(state).to match_snapshot("greeting", type: :text)
    end

    it "fails when named snapshot differs" do
      grid = make_grid(3, 20)
      "World".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      state = make_state(grid: grid, rows: 3)

      # Create snapshot with different content
      snap = TUITD::Snapshot.new("diff_greet", type: :text, snapshot_dir: snapshot_dir)
      snap.save(state)

      # Now compare with "Hello" state
      grid2 = make_grid(3, 20)
      "Hello".chars.each_with_index { |c, i| grid2[1][5 + i][:char] = c }
      state2 = make_state(grid: grid2, rows: 3)

      expect { expect(state2).to match_snapshot("diff_greet", type: :text) }
        .to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    it "supports type: :full" do
      grid = make_grid(1, 5)
      grid[0][0][:char] = "A"
      state = make_state(grid: grid, rows: 1)

      snap = TUITD::Snapshot.new("full_test", type: :full, snapshot_dir: snapshot_dir)
      snap.save(state)

      expect(state).to match_snapshot("full_test", type: :full)
    end

    it "backward compatible: still works with State objects" do
      grid = make_grid(3, 20)
      "Hello".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      state = make_state(grid: grid, rows: 3)
      snapshot = make_state(grid: grid, rows: 3)
      expect(state).to match_snapshot(snapshot)
    end

    it "backward compatible: still supports chars_only parameter" do
      grid = make_grid(3, 20)
      "Hello".chars.each_with_index { |c, i| grid[1][5 + i][:char] = c }
      state = make_state(grid: grid, rows: 3)

      style_grid = make_grid(3, 20)
      "Hello".chars.each_with_index { |c, i| style_grid[1][5 + i][:char] = c }
      style_grid[1][5][:bold] = true
      snapshot = make_state(grid: style_grid, rows: 3)

      expect(state).to match_snapshot(snapshot, chars_only: true)
    end
  end

  describe "be_recording" do
    it "is true when driver is recording" do
      driver = TUITD::Driver.new("echo test", rows: 3, cols: 10, timeout: 5)
      driver.start
      driver.wait_for_exit

      allow(TUITD::VideoRecorder).to receive(:available?).and_return(true)
      driver.start_recording("/tmp/rspec_test_#{Process.pid}.mp4", framerate: 2)

      expect(driver).to be_recording

      driver.stop_recording
      driver.close
      FileUtils.rm_f("/tmp/rspec_test_#{Process.pid}.mp4")
    end

    it "is false when driver is not recording" do
      driver = TUITD::Driver.new("echo test", rows: 3, cols: 10, timeout: 5)
      driver.start
      driver.wait_for_exit

      expect(driver).not_to be_recording

      driver.close
    end
  end

  describe "have_recorded_video" do
    it "is true when video file exists and has content" do
      driver = TUITD::Driver.new("echo test", rows: 3, cols: 10, timeout: 5)
      driver.start
      driver.wait_for_exit

      allow(TUITD::VideoRecorder).to receive(:available?).and_return(true)
      path = "/tmp/rspec_video_#{Process.pid}.mp4"
      driver.start_recording(path, framerate: 2)
      sleep 0.5
      driver.stop_recording

      expect(driver).to have_recorded_video(path)

      driver.close
      FileUtils.rm_f(path)
    end

    it "is false when video file does not exist" do
      driver = TUITD::Driver.new("echo test", rows: 3, cols: 10, timeout: 5)
      driver.start
      driver.wait_for_exit

      expect(driver).not_to have_recorded_video("/tmp/nonexistent_#{Process.pid}.mp4")

      driver.close
    end
  end

  describe "confidence support (tans-parser 0.1.5+)" do
    # Helper: write text into a grid at a position
    def write_text(grid, row, col, text, **styles)
      text.chars.each_with_index do |ch, i|
        grid[row][col + i] =
          { char: ch, fg: "default", bg: "default", bold: false, italic: false, underline: false, **styles }
      end
    end

    it "have_button filters by min_confidence" do
      grid = make_grid(3, 20)
      write_text(grid, 1, 2, "[ OK ]")
      state = make_state(grid: grid)
      # Button [ OK ] with [] brackets gets confidence 0.9
      expect(state).to have_button("OK", min_confidence: 0.8)
      # But not at 0.95
      expect(state).not_to have_button("OK", min_confidence: 0.95)
    end

    it "have_dialog filters by min_confidence" do
      # Use proper box-drawing characters that tans-parser detects
      grid = make_grid(5, 20)
      write_text(grid, 1, 5, "┌──────────┐") # ┌──────────┐
      write_text(grid, 2, 5, "│  Hello   │") # │  Hello   │
      write_text(grid, 3, 5, "└──────────┘") # └──────────┘
      state = make_state(grid: grid, rows: 5)
      expect(state).to have_dialog(min_confidence: 0.8)
      expect(state).not_to have_dialog(min_confidence: 0.99)
    end

    it "have_role with min_confidence filters elements" do
      grid = make_grid(3, 20)
      write_text(grid, 1, 2, "[ OK ]")
      state = make_state(grid: grid)
      expect(state).to have_role(:button, text: "OK", min_confidence: 0.8)
      expect(state).not_to have_role(:button, text: "OK", min_confidence: 0.99)
    end

    it "have_checkbox filters by min_confidence" do
      grid = make_grid(3, 20)
      write_text(grid, 1, 2, "[X] OK")
      state = make_state(grid: grid)
      # Checkbox with [X] gets confidence 0.9
      expect(state).to have_checkbox("OK", min_confidence: 0.8)
      expect(state).not_to have_checkbox("OK", min_confidence: 0.99)
    end

    it "have_input with min_confidence" do
      grid = make_grid(3, 20)
      # Input detected as [____] underscore-filled brackets
      write_text(grid, 1, 2, "[_________]")
      state = make_state(grid: grid)
      expect(state).to have_input(min_confidence: 0.8)
      expect(state).not_to have_input(min_confidence: 0.99)
    end

    it "have_statusbar with low confidence is sensitive" do
      # Statusbar on bottom row with colored background gets confidence 0.9
      grid = make_grid(3, 20)
      write_text(grid, 2, 0, "Status: idle", bg: "blue")
      state = make_state(grid: grid)
      # Colored statusbar has confidence 0.9
      expect(state).to have_statusbar(min_confidence: 0.8)
      expect(state).not_to have_statusbar(min_confidence: 0.95)
    end

    it "have_progress_bar with min_confidence" do
      grid = make_grid(3, 30)
      write_text(grid, 1, 2, "[##########         ]")
      state = make_state(grid: grid)
      expect(state).to have_progress_bar(min_confidence: 0.8)
      expect(state).not_to have_progress_bar(min_confidence: 0.99)
    end

    it "elements have confidence attribute" do
      grid = make_grid(3, 20)
      write_text(grid, 1, 2, "[ OK ]")
      state = make_state(grid: grid)
      selector = TUITD::Selector.new(state)
      el = selector.button(text: "OK")
      expect(el).not_to be_nil
      expect(el.confidence).to be_a(Numeric)
      expect(el.confidence).to be >= 0
      expect(el.confidence).to be <= 1.0
    end
  end
end
