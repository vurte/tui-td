# frozen_string_literal: true

require "spec_helper"

RSpec.describe TUITD::Selector do
  def make_grid(rows, cols)
    Array.new(rows) do
      Array.new(cols) do
        { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false }
      end
    end
  end

  def make_state(grid: nil, rows: 5, cols: 30)
    TUITD::State.new(
      size: { rows: rows, cols: cols },
      cursor: { row: 0, col: 0 },
      rows: grid || make_grid(rows, cols),
    )
  end

  def write_line(grid, row, text, **opts)
    text.chars.each_with_index do |c, i|
      grid[row][i] = { char: c, fg: "default", bg: "default", bold: false, italic: false, underline: false }.merge(opts)
    end
  end

  describe "delegation to TansParser::Selector" do
    it "detects buttons via delegated Selector" do
      grid = make_grid(3, 20)
      write_line(grid, 1, "[ OK ]")
      selector = described_class.new(make_state(grid: grid))
      buttons = selector.buttons
      expect(buttons.size).to eq(1)
      expect(buttons.first).to be_a(TUITD::Element)
      expect(buttons.first.role).to eq(:button)
      expect(buttons.first.text).to eq("OK")
    end

    it "detects checkboxes via delegated Selector" do
      grid = make_grid(5, 30)
      write_line(grid, 2, "[x] Enable logging")
      selector = described_class.new(make_state(grid: grid))
      checkboxes = selector.checkboxes
      expect(checkboxes.size).to eq(1)
      expect(checkboxes.first.text).to eq("Enable logging")
      expect(checkboxes.first.checked).to be true
    end

    it "detects dialogs via delegated Selector" do
      grid = make_grid(5, 20)
      write_line(grid, 1, "┌──────────┐")
      write_line(grid, 2, "│  Hello   │")
      write_line(grid, 3, "└──────────┘")
      selector = described_class.new(make_state(grid: grid))
      dialogs = selector.dialogs
      expect(dialogs.size).to eq(1)
      expect(dialogs.first.role).to eq(:dialog)
      expect(dialogs.first.text).to include("Hello")
    end
  end

  describe "#within" do
    it "filters elements within a bounding box" do
      grid = make_grid(10, 30)
      write_line(grid, 1, "┌──────────┐")
      write_line(grid, 2, "│ [ OK ]   │")
      write_line(grid, 3, "└──────────┘")
      write_line(grid, 5, "[Cancel]")
      selector = described_class.new(make_state(grid: grid))
      dialog = selector.dialogs.first
      scoped = selector.within(dialog.row, dialog.col, dialog.width, dialog.height)
      expect(scoped.buttons.size).to eq(1)
      expect(scoped.buttons.first.text).to eq("OK")
    end
  end

  describe TUITD::Element do
    it "is TansParser::Element" do
      expect(described_class).to equal(TansParser::Element)
    end

    it "excludes nil values from to_h" do
      el = described_class.new(role: :button, text: "OK", row: 0, col: 0, width: 4, height: 1)
      hash = el.to_h
      expect(hash).to include(:role, :text, :row, :col, :width, :height)
      expect(hash).not_to have_key(:checked)
    end
  end
end
