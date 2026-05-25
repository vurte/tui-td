# frozen_string_literal: true

require "spec_helper"
require "chunky_png"

RSpec.describe TUITD::Screenshot do
  let(:empty_state) do
    {
      size: { rows: 3, cols: 5 },
      cursor: { row: 0, col: 0 },
      rows: Array.new(3) do
        Array.new(5) { { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false } }
      end,
    }
  end

  let(:output_path) { "/tmp/tui_td_test_screenshot.png" }

  after do
    FileUtils.rm_f(output_path)
  end

  describe "#render" do
    it "produces a valid PNG for an empty terminal" do
      described_class.new(empty_state).render(output_path)
      expect(File).to exist(output_path)
      expect(File.size(output_path)).to be > 0

      png = ChunkyPNG::Image.from_file(output_path)
      expect(png.width).to eq(5 * 8)
      expect(png.height).to eq(3 * 16)
    end

    it "renders a single character" do
      state = Marshal.load(Marshal.dump(empty_state))
      state[:rows][0][0][:char] = "A"
      state[:rows][0][0][:fg] = "white"

      described_class.new(state).render(output_path)
      png = ChunkyPNG::Image.from_file(output_path)

      # The 'A' glyph should produce some white pixels in the first cell
      white = ChunkyPNG::Color.rgb(0xAA, 0xAA, 0xAA)
      white_pixels = 0
      (0...16).each do |y|
        (0...8).each do |x|
          white_pixels += 1 if png[x, y] == white
        end
      end
      expect(white_pixels).to be > 0
    end

    it "renders background color" do
      state = Marshal.load(Marshal.dump(empty_state))
      state[:rows][0][0][:char] = " "
      state[:rows][0][0][:bg] = "red"

      described_class.new(state).render(output_path)
      png = ChunkyPNG::Image.from_file(output_path)

      red = ChunkyPNG::Color.rgb(0xAA, 0x00, 0x00)
      mid_pixel = png[4, 8] # center of first cell
      expect(mid_pixel).to eq(red)
    end

    it "renders bold text wider (overstrike)" do
      normal_state = Marshal.load(Marshal.dump(empty_state))
      normal_state[:rows][0][0][:char] = "|"
      normal_state[:rows][0][0][:fg] = "white"

      bold_state = Marshal.load(Marshal.dump(empty_state))
      bold_state[:rows][0][0][:char] = "|"
      bold_state[:rows][0][0][:fg] = "white"
      bold_state[:rows][0][0][:bold] = true

      normal_path = "/tmp/tui_td_normal.png"
      bold_path = "/tmp/tui_td_bold.png"
      described_class.new(normal_state).render(normal_path)
      described_class.new(bold_state).render(bold_path)

      normal = ChunkyPNG::Image.from_file(normal_path)
      bold = ChunkyPNG::Image.from_file(bold_path)

      white = ChunkyPNG::Color.rgb(0xAA, 0xAA, 0xAA)
      normal_colored = 0
      bold_colored = 0
      (0...16).each do |y|
        (0...8).each do |x|
          normal_colored += 1 if normal[x, y] == white
          bold_colored += 1 if bold[x, y] == white
        end
      end

      # Bold should have roughly 2x the pixels (overstrike right by 1px)
      expect(bold_colored).to be > normal_colored
    ensure
      FileUtils.rm_f(normal_path)
      FileUtils.rm_f(bold_path)
    end

    it "renders underline" do
      state = Marshal.load(Marshal.dump(empty_state))
      state[:rows][0][0][:char] = "A"
      state[:rows][0][0][:fg] = "green"
      state[:rows][0][0][:underline] = true

      described_class.new(state).render(output_path)
      png = ChunkyPNG::Image.from_file(output_path)

      green = ChunkyPNG::Color.rgb(0x00, 0xAA, 0x00)
      underline_pixels = 0
      # Underline is at y = py + CELL_H - 2 = 14
      8.times { |x| underline_pixels += 1 if png[x, 14] == green }
      expect(underline_pixels).to be > 0
    end
  end

  describe "color resolution" do
    let(:screenshot) { described_class.new(empty_state) }

    def resolve(name)
      screenshot.send(:resolve_color, name, TUITD::Screenshot::DEFAULT_FG)
    end

    it "resolves standard ANSI names" do
      expect(resolve("red")).to eq([0xAA, 0x00, 0x00])
      expect(resolve("green")).to eq([0x00, 0xAA, 0x00])
      expect(resolve("blue")).to eq([0x00, 0x00, 0xAA])
      expect(resolve("white")).to eq([0xAA, 0xAA, 0xAA])
      expect(resolve("black")).to eq([0x00, 0x00, 0x00])
    end

    it "resolves bright ANSI names" do
      expect(resolve("bright_red")).to eq([0xFF, 0x55, 0x55])
      expect(resolve("bright_green")).to eq([0x55, 0xFF, 0x55])
      expect(resolve("bright_white")).to eq([0xFF, 0xFF, 0xFF])
    end

    it "resolves TrueColor hex format" do
      expect(resolve("#ff6432")).to eq([0xFF, 0x64, 0x32])
      expect(resolve("#000000")).to eq([0x00, 0x00, 0x00])
      expect(resolve("#ABCDEF")).to eq([0xAB, 0xCD, 0xEF])
    end

    it "resolves 256-color cube values" do
      # color16 = first cube entry (0,0,0) = [0x00, 0x00, 0x00]
      expect(resolve("color16")).to eq([0x00, 0x00, 0x00])
      # color51 = cube index 35: r=0,g=1,b=5 (index from 16: 35→r=(35/36)=0,g=(35/6)%6=5,b=5)
      # Actually: index 51: 51-16=35, r=35/36=0, g=35/6%6=5, b=35%6=5
      expect(resolve("color51")).to eq([0x00, 0xFF, 0xFF])
    end

    it "resolves 256-color grayscale values" do
      # color232 = first grayscale, v = 8
      expect(resolve("color232")).to eq([8, 8, 8])
      # color255 = last grayscale, v = 8 + 23*10 = 238
      expect(resolve("color255")).to eq([238, 238, 238])
    end

    it "resolves default to fallback" do
      expect(resolve("default")).to eq(TUITD::Screenshot::DEFAULT_FG)
    end

    it "resolves unknown colors to fallback" do
      expect(resolve("not_a_color")).to eq(TUITD::Screenshot::DEFAULT_FG)
    end

    it "resolves standard 16-color palette via xterm_256 index" do
      expect(resolve("color0")).to eq([0x00, 0x00, 0x00])   # black
      expect(resolve("color1")).to eq([0xAA, 0x00, 0x00])   # red
      expect(resolve("color7")).to eq([0xAA, 0xAA, 0xAA])   # white
      expect(resolve("color9")).to eq([0xFF, 0x55, 0x55])   # bright_red
    end
  end

  describe "font data integrity" do
    it "has font data for all printable ASCII characters" do
      font = described_class.send(:const_get, :FONT)
      expect(font.length).to eq(95 * 16) # 95 chars × 16 rows
    end

    it "space character is all zeros" do
      font = described_class.send(:const_get, :FONT)
      space_rows = font[0, 16]
      expect(space_rows).to all(eq(0))
    end

    it "exclamation mark has some pixels set" do
      font = described_class.send(:const_get, :FONT)
      bang_rows = font[16, 16] # '!' is index 1 (33-32)
      expect(bang_rows.any? { |r| r != 0 }).to be true
    end
  end

  describe "ANSI_RGB completeness" do
    it "has entries for all 16 standard colors" do
      expected = %w[black red green yellow blue magenta cyan white
                    bright_black bright_red bright_green bright_yellow
                    bright_blue bright_magenta bright_cyan bright_white]
      expected.each do |name|
        expect(described_class.send(:const_get, :ANSI_RGB)).to have_key(name)
      end
    end
  end

  describe "box drawing character rendering" do
    it "renders Unicode box drawing characters" do
      state = Marshal.load(Marshal.dump(empty_state))
      state[:rows][0][0][:char] = "─" # horizontal light
      state[:rows][0][0][:fg] = "white"

      described_class.new(state).render(output_path)
      png = ChunkyPNG::Image.from_file(output_path)

      white = ChunkyPNG::Color.rgb(0xAA, 0xAA, 0xAA)

      # The center of the first cell is at cx=4, cy=8
      # '─' should draw a horizontal line through the middle (cy=8)
      line_pixels = 0
      8.times do |x|
        line_pixels += 1 if png[x, 8] == white
      end
      expect(line_pixels).to be > 0
    end

    it "renders double corners and lines" do
      state = Marshal.load(Marshal.dump(empty_state))
      state[:rows][0][0][:char] = "╔" # double down-right corner
      state[:rows][0][0][:fg] = "white"

      described_class.new(state).render(output_path)
      png = ChunkyPNG::Image.from_file(output_path)

      white = ChunkyPNG::Color.rgb(0xAA, 0xAA, 0xAA)

      # Outer double corner top-left is at (cx-2, cy-2) -> (2, 6)
      expect(png[2, 6]).to eq(white)
      # Inner double corner top-left is at (cx+2, cy+2) -> (6, 10)
      expect(png[6, 10]).to eq(white)
    end

    it "renders rounded corners" do
      state = Marshal.load(Marshal.dump(empty_state))
      state[:rows][0][0][:char] = "╭"
      state[:rows][0][0][:fg] = "white"

      described_class.new(state).render(output_path)
      png = ChunkyPNG::Image.from_file(output_path)

      white = ChunkyPNG::Color.rgb(0xAA, 0xAA, 0xAA)
      # ╭ (top-left rounded corner) should draw:
      # - px+5..px+7 at py+8 (horizontal right segment)
      # - py+10..py+15 at px+4 (vertical down segment)
      # - px+4, py+9 (arc)
      # - px+5, py+9 (connection)
      expect(png[6, 8]).to eq(white)
      expect(png[4, 12]).to eq(white)
      expect(png[4, 9]).to eq(white)
      expect(png[5, 9]).to eq(white)
      # And the sharp corner pixel px+4, py+8 should NOT be set (remain black)
      expect(png[4, 8]).to eq(ChunkyPNG::Color::BLACK)
    end

    it "renders new special characters" do
      state = {
        size: { rows: 2, cols: 30 },
        cursor: { row: 0, col: 0 },
        rows: Array.new(2) do
          Array.new(30) { { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false } }
        end,
      }
      chars = ["▀", "▲", "✓", "▄", "█", "▼", "✗", "↑", "↓", "→", "⚙", "⚠", "…", "—", "⠋", "←", "▌", "▐", "☐", "☑", "☒",
               "ℹ", "✖",]
      chars.each_with_index do |char, idx|
        state[:rows][0][idx][:char] = char
        state[:rows][0][idx][:fg] = "white"
      end

      described_class.new(state).render(output_path)
      png = ChunkyPNG::Image.from_file(output_path)

      white = ChunkyPNG::Color.rgb(0xAA, 0xAA, 0xAA)

      # ▀ (cell 0,0: px=0)
      expect(png[2, 2]).to eq(white)
      expect(png[2, 10]).to eq(ChunkyPNG::Color::BLACK)

      # ▲ (cell 0,1: px=8)
      expect(png[12, 5]).to eq(white)

      # ✓ (cell 0,2: px=16)
      expect(png[20, 10]).to eq(white)

      # ▄ (cell 0,3: px=24)
      expect(png[26, 10]).to eq(white)
      expect(png[26, 2]).to eq(ChunkyPNG::Color::BLACK)

      # █ (cell 0,4: px=32)
      expect(png[34, 2]).to eq(white)
      expect(png[34, 10]).to eq(white)

      # ▼ (cell 0,5: px=40)
      expect(png[44, 7]).to eq(white)

      # ✗ (cell 0,6: px=48)
      expect(png[52, 8]).to eq(white)

      # ↑ (cell 0,7: px=56)
      expect(png[60, 4]).to eq(white)

      # ↓ (cell 0,8: px=64)
      expect(png[68, 11]).to eq(white)

      # → (cell 0,9: px=72)
      expect(png[77, 8]).to eq(white)

      # ⚙ (cell 0,10: px=80)
      expect(png[84, 6]).to eq(white)

      # ⚠ (cell 0,11: px=88)
      expect(png[92, 3]).to eq(white)

      # … (cell 0,12: px=96)
      expect(png[100, 12]).to eq(white)

      # — (cell 0,13: px=104)
      expect(png[106, 8]).to eq(white)

      # ⠋ (cell 0,14: px=112)
      expect(png[114, 3]).to eq(white)

      # ← (cell 0,15: px=120)
      expect(png[124, 8]).to eq(white)
      expect(png[121, 8]).to eq(white)
      expect(png[122, 7]).to eq(white)
      expect(png[123, 6]).to eq(white)

      # ▌ (cell 0,16: px=128)
      expect(png[128 + 2, 2]).to eq(white)
      expect(png[128 + 6, 2]).to eq(ChunkyPNG::Color::BLACK)

      # ▐ (cell 0,17: px=136)
      expect(png[136 + 2, 2]).to eq(ChunkyPNG::Color::BLACK)
      expect(png[136 + 6, 2]).to eq(white)

      # ☐ (cell 0,18: px=144)
      expect(png[144 + 1, 4]).to eq(white)
      expect(png[144 + 3, 7]).to eq(ChunkyPNG::Color::BLACK)

      # ☑ (cell 0,19: px=152)
      expect(png[152 + 1, 4]).to eq(white)
      expect(png[152 + 3, 9]).to eq(white)

      # ☒ (cell 0,20: px=160)
      expect(png[160 + 1, 4]).to eq(white)
      expect(png[160 + 3, 7]).to eq(white)

      # ℹ (cell 0,21: px=168)
      expect(png[168 + 1, 6]).to eq(white)
      expect(png[168 + 4, 6]).to eq(white)
      expect(png[168 + 4, 7]).to eq(ChunkyPNG::Color::BLACK)
      expect(png[168 + 4, 8]).to eq(white)

      # ✖ (cell 0,22: px=176)
      expect(png[176 + 3, 8]).to eq(white)
      expect(png[176 + 1, 4]).to eq(white)
      expect(png[176 + 2, 4]).to eq(white)
    end
  end

  describe "cursor rendering" do
    it "renders steady block cursor by inverting colors" do
      state = Marshal.load(Marshal.dump(empty_state))
      state[:cursor_visible] = true
      state[:cursor_style] = 1 # Block
      state[:cursor] = { row: 0, col: 0, visible: true, style: 1 }

      described_class.new(state).render(output_path)
      png = ChunkyPNG::Image.from_file(output_path)

      # Initially empty_state is black (0x000000). Inverted it should be white (0xFFFFFF).
      expect(png[0, 0]).to eq(ChunkyPNG::Color.rgb(255, 255, 255))
    end

    it "renders underline cursor" do
      state = Marshal.load(Marshal.dump(empty_state))
      state[:cursor_visible] = true
      state[:cursor_style] = 3 # Underline
      state[:cursor] = { row: 0, col: 0, visible: true, style: 3 }

      described_class.new(state).render(output_path)
      png = ChunkyPNG::Image.from_file(output_path)

      # Underline is drawn at bottom of cell, e.g. y = CELL_H - 1 = 15
      expect(png[0, 15]).to eq(ChunkyPNG::Color.rgb(255, 255, 255))
    end
  end

  describe "unicode character rendering" do
    let(:empty_state) do
      {
        size: { rows: 1, cols: 5 },
        cursor: { row: 0, col: 0 },
        rows: [
          Array.new(5) { { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false } },
        ],
      }
    end

    before do
      @output_path = "/tmp/tui_td_test_unicode_screenshot.png"
    end

    after do
      FileUtils.rm_f(@output_path)
    end

    it "renders a Greek character (non-ASCII) when Cairo is available" do
      skip "Cairo not available" unless TUITD::CairoRenderer.available?

      state = Marshal.load(Marshal.dump(empty_state))
      state[:rows][0][0][:char] = "α" # Greek alpha
      state[:rows][0][0][:fg] = "white"

      described_class.new(state).render(@output_path)
      png = ChunkyPNG::Image.from_file(@output_path)

      # Cairo anti-aliases, so check for any non-black pixel (not exact white)
      non_black = (0...16).sum { |y| (0...8).count { |x| png[x, y] != ChunkyPNG::Color::BLACK } }
      expect(non_black).to be > 0
    end

    it "renders a CJK character (non-ASCII) when Cairo is available" do
      skip "Cairo not available" unless TUITD::CairoRenderer.available?

      state = Marshal.load(Marshal.dump(empty_state))
      state[:rows][0][0][:char] = "中" # CJK: 中
      state[:rows][0][0][:fg] = "white"

      described_class.new(state).render(@output_path)
      png = ChunkyPNG::Image.from_file(@output_path)

      non_black = (0...16).sum { |y| (0...8).count { |x| png[x, y] != ChunkyPNG::Color::BLACK } }
      expect(non_black).to be > 0
    end

    it "silently drops non-ASCII characters when Cairo is not available" do
      skip "Cairo is available on this system" if TUITD::CairoRenderer.available?

      state = Marshal.load(Marshal.dump(empty_state))
      state[:rows][0][0][:char] = "α"
      state[:rows][0][0][:fg] = "white"

      described_class.new(state).render(@output_path)
      png = ChunkyPNG::Image.from_file(@output_path)

      non_black = (0...16).sum { |y| (0...8).count { |x| png[x, y] != ChunkyPNG::Color::BLACK } }
      expect(non_black).to eq(0)
    end
  end

  describe "unifont character rendering" do
    let(:empty_state) do
      {
        size: { rows: 1, cols: 5 },
        cursor: { row: 0, col: 0 },
        rows: [
          Array.new(5) { { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false } },
        ],
      }
    end

    before do
      @output_path = "/tmp/tui_td_test_unifont_screenshot.png"
    end

    after do
      FileUtils.rm_f(@output_path)
    end

    it "renders a Greek character from Unifont" do
      state = Marshal.load(Marshal.dump(empty_state))
      state[:rows][0][0][:char] = "α" # Greek alpha, in Unifont
      state[:rows][0][0][:fg] = "white"

      described_class.new(state).render(@output_path)
      png = ChunkyPNG::Image.from_file(@output_path)

      non_black = (0...16).sum { |y| (0...8).count { |x| png[x, y] != ChunkyPNG::Color::BLACK } }
      expect(non_black).to be > 0
    end

    it "renders a Cyrillic character from Unifont" do
      state = Marshal.load(Marshal.dump(empty_state))
      state[:rows][0][0][:char] = "Д" # Cyrillic De, in Unifont
      state[:rows][0][0][:fg] = "white"

      described_class.new(state).render(@output_path)
      png = ChunkyPNG::Image.from_file(@output_path)

      non_black = (0...16).sum { |y| (0...8).count { |x| png[x, y] != ChunkyPNG::Color::BLACK } }
      expect(non_black).to be > 0
    end

    it "renders a Turkish character from Unifont" do
      state = Marshal.load(Marshal.dump(empty_state))
      state[:rows][0][0][:char] = "ğ" # Turkish g, in Unifont
      state[:rows][0][0][:fg] = "white"

      described_class.new(state).render(@output_path)
      png = ChunkyPNG::Image.from_file(@output_path)

      non_black = (0...16).sum { |y| (0...8).count { |x| png[x, y] != ChunkyPNG::Color::BLACK } }
      expect(non_black).to be > 0
    end

    it "renders an Arabic character from Unifont" do
      state = Marshal.load(Marshal.dump(empty_state))
      state[:rows][0][0][:char] = "ح" # Arabic, in Unifont
      state[:rows][0][0][:fg] = "white"

      described_class.new(state).render(@output_path)
      png = ChunkyPNG::Image.from_file(@output_path)

      non_black = (0...16).sum { |y| (0...8).count { |x| png[x, y] != ChunkyPNG::Color::BLACK } }
      expect(non_black).to be > 0
    end

    it "renders a Box Drawing character from Unifont" do
      state = Marshal.load(Marshal.dump(empty_state))
      state[:rows][0][0][:char] = "─" # box horizontal, in Unifont
      state[:rows][0][0][:fg] = "white"

      described_class.new(state).render(@output_path)
      png = ChunkyPNG::Image.from_file(@output_path)

      non_black = (0...16).sum { |y| (0...8).count { |x| png[x, y] != ChunkyPNG::Color::BLACK } }
      expect(non_black).to be > 0
    end

    it "renders a Math symbol from Unifont" do
      state = Marshal.load(Marshal.dump(empty_state))
      state[:rows][0][0][:char] = "∑" # sum sign, in Unifont
      state[:rows][0][0][:fg] = "white"

      described_class.new(state).render(@output_path)
      png = ChunkyPNG::Image.from_file(@output_path)

      non_black = (0...16).sum { |y| (0...8).count { |x| png[x, y] != ChunkyPNG::Color::BLACK } }
      expect(non_black).to be > 0
    end

    it "falls back to Cairo for characters not in Unifont" do
      skip "Cairo not available" unless TUITD::CairoRenderer.available?

      state = Marshal.load(Marshal.dump(empty_state))
      state[:rows][0][0][:char] = "中" # CJK: not in Unifont, needs Cairo
      state[:rows][0][0][:fg] = "white"

      described_class.new(state).render(@output_path)
      png = ChunkyPNG::Image.from_file(@output_path)

      non_black = (0...16).sum { |y| (0...8).count { |x| png[x, y] != ChunkyPNG::Color::BLACK } }
      expect(non_black).to be > 0
    end
  end
end
