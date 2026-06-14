# frozen_string_literal: true

require "spec_helper"
require "tui_td/html_renderer"

RSpec.describe TUITD::HtmlRenderer do
  let(:basic_state) do
    {
      size: { rows: 2, cols: 5 },
      cursor: { row: 0, col: 2 },
      rows: [
        [
          { char: "H", fg: "cyan", bg: "default", bold: true, italic: false, underline: false },
          { char: "i", fg: "cyan", bg: "default", bold: true, italic: false, underline: false },
          { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false },
          { char: "X", fg: "red", bg: "default", bold: false, italic: true, underline: false },
          { char: "Y", fg: "default", bg: "blue", bold: false, italic: false, underline: true },
        ],
        [
          { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false },
          { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false },
          { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false },
          { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false },
          { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false },
        ],
      ],
    }
  end

  describe "#to_html" do
    it "returns a self-contained HTML document" do
      html = described_class.new(basic_state).to_html
      expect(html).to include("<!DOCTYPE html>")
      expect(html).to include("<style>")
      expect(html).to include("<pre class=\"term\">")
      expect(html).to include("</html>")
    end

    it "renders characters with HTML escaping" do
      state = {
        size: { rows: 1, cols: 2 },
        cursor: { row: 0, col: 0 },
        rows: [
          [
            { char: "<", fg: "default", bg: "default", bold: false, italic: false, underline: false },
            { char: ">", fg: "default", bg: "default", bold: false, italic: false, underline: false },
          ],
        ],
      }
      html = described_class.new(state).to_html
      expect(html).to include("&lt;")
      expect(html).to include("&gt;")
    end

    it "includes color in inline CSS" do
      state = {
        size: { rows: 1, cols: 1 },
        cursor: { row: 0, col: 0 },
        rows: [
          [{ char: "R", fg: "red", bg: "default", bold: false, italic: false, underline: false }],
        ],
      }
      html = described_class.new(state).to_html
      expect(html).to include("#aa0000")
    end

    it "merges adjacent identically-styled cells into runs" do
      html = described_class.new(basic_state).to_html
      # First two cells ("H" and "i") have same style, should be in one span
      match = html.match(%r{<span[^>]*>Hi</span>})
      expect(match).not_to be_nil, "Expected adjacent cyan bold 'H' and 'i' to be merged into one span"
    end

    it "renders bold and italic styles" do
      state = {
        size: { rows: 1, cols: 2 },
        cursor: { row: 0, col: 0 },
        rows: [
          [
            { char: "B", fg: "default", bg: "default", bold: true, italic: false, underline: false },
            { char: "I", fg: "default", bg: "default", bold: false, italic: true, underline: false },
          ],
        ],
      }
      html = described_class.new(state).to_html
      expect(html).to include("font-weight:bold")
      expect(html).to include("font-style:italic")
    end

    it "renders background color" do
      state = {
        size: { rows: 1, cols: 1 },
        cursor: { row: 0, col: 0 },
        rows: [
          [{ char: "X", fg: "default", bg: "blue", bold: false, italic: false, underline: false }],
        ],
      }
      html = described_class.new(state).to_html
      expect(html).to include("background-color:#0000aa")
    end

    it "renders underline" do
      state = {
        size: { rows: 1, cols: 1 },
        cursor: { row: 0, col: 0 },
        rows: [
          [{ char: "U", fg: "default", bg: "default", bold: false, italic: false, underline: true }],
        ],
      }
      html = described_class.new(state).to_html
      expect(html).to include("text-decoration:underline")
    end

    it "highlights cursor cell" do
      state = {
        size: { rows: 2, cols: 3 },
        cursor: { row: 0, col: 1 },
        rows: [
          [
            { char: "A", fg: "default", bg: "default", bold: false, italic: false, underline: false },
            { char: "B", fg: "default", bg: "default", bold: false, italic: false, underline: false },
            { char: "C", fg: "default", bg: "default", bold: false, italic: false, underline: false },
          ],
          [
            { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false },
            { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false },
            { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false },
          ],
        ],
      }
      html = described_class.new(state).to_html
      expect(html).to include("cursor-cell")
    end

    it "handles empty rows" do
      state = {
        size: { rows: 2, cols: 2 },
        cursor: { row: 0, col: 0 },
        rows: [
          [],
          nil,
        ],
      }
      html = described_class.new(state).to_html
      expect(html).to include("<!DOCTYPE html>")
      expect(html).to include('<span class="line">')
    end

    it "escapes & and double-quote in HTML" do
      state = {
        size: { rows: 1, cols: 4 },
        cursor: { row: 0, col: 0 },
        rows: [
          [
            { char: "&", fg: "default", bg: "default", bold: false, italic: false, underline: false },
            { char: '"', fg: "default", bg: "default", bold: false, italic: false, underline: false },
            { char: "<", fg: "default", bg: "default", bold: false, italic: false, underline: false },
            { char: ">", fg: "default", bg: "default", bold: false, italic: false, underline: false },
          ],
        ],
      }
      html = described_class.new(state).to_html
      expect(html).to include("&amp;")
      expect(html).to include("&quot;")
      expect(html).to include("&lt;")
      expect(html).to include("&gt;")
    end

    it "renders 256-color foreground" do
      state = {
        size: { rows: 1, cols: 1 },
        cursor: { row: 0, col: 0 },
        rows: [
          [{ char: "C", fg: "color82", bg: "default", bold: false, italic: false, underline: false }],
        ],
      }
      html = described_class.new(state).to_html
      expect(html).to include("color:#")
    end

    it "renders state with string keys" do
      state = {
        "size" => { "rows" => 1, "cols" => 1 },
        "cursor" => { "row" => 0, "col" => 0 },
        "rows" => [
          [{ "char" => "S", "fg" => "red", "bg" => "default", "bold" => false, "italic" => false,
             "underline" => false, }],
        ],
      }
      html = described_class.new(state).to_html
      expect(html).to include("#aa0000")
    end

    it "renders blink animations for blinking cells" do
      state = {
        size: { rows: 1, cols: 2 },
        cursor: { row: 0, col: 1 },
        rows: [
          [
            { char: "B", fg: "default", bg: "default", bold: false, italic: false, underline: false, blink: true },
            { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false, blink: false },
          ],
        ],
      }
      html = described_class.new(state).to_html
      expect(html).to include("class=\"term-blink\"")
    end

    it "renders hidden cursor class" do
      state = {
        size: { rows: 1, cols: 1 },
        cursor: { row: 0, col: 0, visible: false },
        rows: [
          [{ char: "A", fg: "default", bg: "default", bold: false, italic: false, underline: false }],
        ],
      }
      html = described_class.new(state).to_html
      expect(html).to include("cursor-hidden")
    end

    it "renders all cursor styles (block, underline, bar)" do
      # style 0 or 1: blinking block
      state_s0 = {
        size: { rows: 1, cols: 1 },
        cursor: { row: 0, col: 0, style: 1 },
        rows: [[{ char: "A", fg: "default", bg: "default", bold: false, italic: false, underline: false }]],
      }
      html_s0 = described_class.new(state_s0).to_html
      expect(html_s0).to include("cursor-block blink")

      # style 2: steady block
      state_s2 = {
        size: { rows: 1, cols: 1 },
        cursor: { row: 0, col: 0, style: 2 },
        rows: [[{ char: "A", fg: "default", bg: "default", bold: false, italic: false, underline: false }]],
      }
      html_s2 = described_class.new(state_s2).to_html
      expect(html_s2).to include("cursor-block")
      expect(html_s2).not_to include("cursor-block blink")

      # style 3: blinking underline
      state_s3 = {
        size: { rows: 1, cols: 1 },
        cursor: { row: 0, col: 0, style: 3 },
        rows: [[{ char: "A", fg: "default", bg: "default", bold: false, italic: false, underline: false }]],
      }
      html_s3 = described_class.new(state_s3).to_html
      expect(html_s3).to include("cursor-underline blink")

      # style 4: steady underline
      state_s4 = {
        size: { rows: 1, cols: 1 },
        cursor: { row: 0, col: 0, style: 4 },
        rows: [[{ char: "A", fg: "default", bg: "default", bold: false, italic: false, underline: false }]],
      }
      html_s4 = described_class.new(state_s4).to_html
      expect(html_s4).to include("cursor-underline")
      expect(html_s4).not_to include("cursor-underline blink")

      # style 5: blinking bar
      state_s5 = {
        size: { rows: 1, cols: 1 },
        cursor: { row: 0, col: 0, style: 5 },
        rows: [[{ char: "A", fg: "default", bg: "default", bold: false, italic: false, underline: false }]],
      }
      html_s5 = described_class.new(state_s5).to_html
      expect(html_s5).to include("cursor-bar blink")

      # style 6: steady bar
      state_s6 = {
        size: { rows: 1, cols: 1 },
        cursor: { row: 0, col: 0, style: 6 },
        rows: [[{ char: "A", fg: "default", bg: "default", bold: false, italic: false, underline: false }]],
      }
      html_s6 = described_class.new(state_s6).to_html
      expect(html_s6).to include("cursor-bar")
      expect(html_s6).not_to include("cursor-bar blink")
    end
  end

  describe "#render" do
    it "writes HTML to a file" do
      path = "/tmp/tui_td_html_test_#{Process.pid}.html"
      described_class.new(basic_state).render(path)
      expect(File.exist?(path)).to be true
      content = File.read(path)
      expect(content).to include("<!DOCTYPE html>")
    ensure
      File.delete(path) if path && File.exist?(path)
    end
  end
end
