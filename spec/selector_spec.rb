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

  describe "#within (tans-parser ScopedSelector)" do
    it "filters elements within an element's bounding box" do
      grid = make_grid(10, 30)
      write_line(grid, 1, "┌──────────┐")
      write_line(grid, 2, "│ [ OK ]   │")
      write_line(grid, 3, "└──────────┘")
      write_line(grid, 5, "[Cancel]")
      selector = described_class.new(make_state(grid: grid))
      dialog = selector.dialogs.first
      scoped = selector.within(dialog)
      expect(scoped.buttons.size).to eq(1)
      expect(scoped.buttons.first.text).to eq("OK")
    end

    it "scoped find_text reads only the grid slice" do
      grid = make_grid(10, 30)
      write_line(grid, 1, "┌──────────┐")
      write_line(grid, 2, "│ [ OK ]   │")
      write_line(grid, 3, "└──────────┘")
      selector = described_class.new(make_state(grid: grid))
      dialog = selector.dialogs.first
      scoped = selector.within(dialog)
      expect(scoped.find_text("OK").size).to eq(1)
    end

    it "block form works" do
      grid = make_grid(10, 30)
      write_line(grid, 1, "┌──────────┐")
      write_line(grid, 2, "│ [ OK ]   │")
      write_line(grid, 3, "└──────────┘")
      selector = described_class.new(make_state(grid: grid))
      dialog = selector.dialogs.first
      result = selector.within(dialog) { |s| s.buttons.first.text }
      expect(result).to eq("OK")
    end
  end

  describe "new roles from tans-parser 0.1.2" do
    it "detects input fields: [____]" do
      grid = make_grid(3, 30)
      write_line(grid, 1, "Name: [________]")
      selector = described_class.new(make_state(grid: grid))
      inputs = selector.inputs
      expect(inputs.size).to eq(1)
      expect(inputs.first.role).to eq(:input)
    end

    it "detects labels: Name:" do
      grid = make_grid(3, 20)
      write_line(grid, 1, "Username:")
      selector = described_class.new(make_state(grid: grid))
      labels = selector.labels
      expect(labels.size).to eq(1)
      expect(labels.first.role).to eq(:label)
      expect(labels.first.text).to include("Username")
    end

    it "detects menu bars: spaced words on top rows" do
      grid = make_grid(3, 40)
      write_line(grid, 0, "File    Edit    View    Help")
      selector = described_class.new(make_state(grid: grid))
      menus = selector.menus
      expect(menus.size).to be >= 1
      expect(menus.first.role).to eq(:menu)
    end

    it "detects menu dropdown items: > Item" do
      grid = make_grid(5, 20)
      write_line(grid, 1, "> New File")
      write_line(grid, 2, "> Open")
      selector = described_class.new(make_state(grid: grid))
      menus = selector.menus
      expect(menus.size).to be >= 1
      expect(menus.map(&:role).uniq).to eq([:menu])
    end

    it "detects tabs: [Tab1] [Tab2] [Tab3]" do
      grid = make_grid(3, 40)
      write_line(grid, 0, "[File] [Edit] [View]")
      selector = described_class.new(make_state(grid: grid))
      tabs = selector.tabs
      expect(tabs.size).to be >= 1
      expect(tabs.first.role).to eq(:tab)
    end

    it "tab elements include focused attribute" do
      grid = make_grid(3, 40)
      write_line(grid, 0, "[File] [Edit] [View]")
      selector = described_class.new(make_state(grid: grid))
      tabs = selector.tabs
      expect(tabs).not_to be_empty
    end
  end

  describe "filter kwargs on get_by_role" do
    it "filters by text:" do
      grid = make_grid(5, 30)
      write_line(grid, 1, "[ OK ]  (Cancel)")
      selector = described_class.new(make_state(grid: grid))
      results = selector.get_by_role(:button, text: "OK")
      expect(results.size).to eq(1)
      expect(results.first.text).to eq("OK")
    end

    it "filters by checked: true" do
      grid = make_grid(5, 30)
      write_line(grid, 1, "[x] Item 1")
      write_line(grid, 2, "[ ] Item 2")
      selector = described_class.new(make_state(grid: grid))
      results = selector.get_by_role(:checkbox, checked: true)
      expect(results.size).to eq(1)
      expect(results.first.text).to eq("Item 1")
    end

    it "filters by checked: false" do
      grid = make_grid(5, 30)
      write_line(grid, 1, "[x] Item 1")
      write_line(grid, 2, "[ ] Item 2")
      selector = described_class.new(make_state(grid: grid))
      results = selector.get_by_role(:checkbox, checked: false)
      expect(results.size).to eq(1)
      expect(results.first.text).to eq("Item 2")
    end

    it "convenience methods accept filter kwargs" do
      grid = make_grid(3, 20)
      write_line(grid, 1, "[ OK ]")
      selector = described_class.new(make_state(grid: grid))
      result = selector.button(text: "OK")
      expect(result).to be_a(TUITD::Element)
      expect(result&.text).to eq("OK")
    end
  end

  describe "singular convenience methods" do
    let(:grid) { make_grid(8, 40) }
    let(:selector) { described_class.new(make_state(grid: grid)) }

    before do
      write_line(grid, 1, "[ OK ]")
      write_line(grid, 2, "[x] Enable")
      write_line(grid, 3, "┌──────────┐")
      write_line(grid, 4, "│  Dialog  │")
      write_line(grid, 5, "└──────────┘")
      write_line(grid, 6, "[________]")
    end

    it "button returns first match" do
      expect(selector.button).to be_a(TUITD::Element)
      expect(selector.button.role).to eq(:button)
    end

    it "checkbox returns first match" do
      expect(selector.checkbox).to be_a(TUITD::Element)
      expect(selector.checkbox.role).to eq(:checkbox)
    end

    it "dialog returns first match" do
      expect(selector.dialog).to be_a(TUITD::Element)
      expect(selector.dialog.role).to eq(:dialog)
    end

    it "input returns first match" do
      expect(selector.input).to be_a(TUITD::Element)
      expect(selector.input.role).to eq(:input)
    end

    it "singular methods return nil when no match" do
      empty_grid = make_grid(2, 10)
      empty_selector = described_class.new(make_state(grid: empty_grid))
      expect(empty_selector.button).to be_nil
      expect(empty_selector.checkbox).to be_nil
      expect(empty_selector.dialog).to be_nil
      expect(empty_selector.input).to be_nil
      expect(empty_selector.label).to be_nil
      expect(empty_selector.menu).to be_nil
      expect(empty_selector.tab).to be_nil
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

    describe "action methods" do
      it "click returns action hash with center coordinates" do
        el = described_class.new(role: :button, text: "OK", row: 5, col: 10, width: 6, height: 1)
        action = el.click
        expect(action[:action]).to eq(:click)
        expect(action[:col]).to eq(13) # 10 + 6/2
        expect(action[:row]).to eq(5)
      end

      it "type returns action hash with text" do
        el = described_class.new(role: :input, row: 0, col: 0, width: 10, height: 1)
        action = el.type("hello")
        expect(action[:action]).to eq(:type)
        expect(action[:text]).to eq("hello")
      end

      it "press_key returns action hash with key" do
        el = described_class.new(role: :button, row: 0, col: 0, width: 6, height: 1)
        action = el.press_key(:enter)
        expect(action[:action]).to eq(:press_key)
        expect(action[:key]).to eq(:enter)
      end
    end

    describe "predicates" do
      it "checked? returns boolean always" do
        expect(described_class.new(role: :checkbox, checked: true).checked?).to be true
        expect(described_class.new(role: :checkbox).checked?).to be false
      end

      it "disabled? returns boolean always" do
        expect(described_class.new(role: :button, disabled: true).disabled?).to be true
        expect(described_class.new(role: :button).disabled?).to be false
      end
    end

    describe "bounds" do
      it "returns position hash" do
        el = described_class.new(role: :dialog, row: 1, col: 2, width: 20, height: 10)
        expect(el.bounds).to eq({ row: 1, col: 2, width: 20, height: 10 })
      end
    end

    describe "disabled field" do
      it "is included in to_h when present" do
        el = described_class.new(role: :button, text: "OK", row: 0, col: 0, width: 4, height: 1, disabled: true)
        expect(el.to_h).to include(disabled: true)
      end
    end
  end
end
