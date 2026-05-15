# frozen_string_literal: true

require "spec_helper"
require "tui_td/html_renderer"

RSpec.describe TUITD::HtmlRenderer do
  let(:basic_state) do
    {
      size: { rows: 2, cols: 5 },
      cursor: { row: 0, col: 0 },
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
      match = html.match(/<span[^>]*>Hi<\/span>/)
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
