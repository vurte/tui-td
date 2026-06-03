# frozen_string_literal: true

require "spec_helper"
require "tui_td/matchers"

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
end
