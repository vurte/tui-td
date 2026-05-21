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
    File.delete(output_path) if File.exist?(output_path)
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
      mid_pixel = png[4, 8]  # center of first cell
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
      File.delete(normal_path) if File.exist?(normal_path)
      File.delete(bold_path) if File.exist?(bold_path)
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
      font = TUITD::Screenshot.send(:const_get, :FONT)
      expect(font.length).to eq(95 * 16)  # 95 chars × 16 rows
    end

    it "space character is all zeros" do
      font = TUITD::Screenshot.send(:const_get, :FONT)
      space_rows = font[0, 16]
      expect(space_rows).to all(eq(0))
    end

    it "exclamation mark has some pixels set" do
      font = TUITD::Screenshot.send(:const_get, :FONT)
      bang_rows = font[16, 16]  # '!' is index 1 (33-32)
      expect(bang_rows.any? { |r| r != 0 }).to be true
    end
  end

  describe "ANSI_RGB completeness" do
    it "has entries for all 16 standard colors" do
      expected = %w[black red green yellow blue magenta cyan white
                    bright_black bright_red bright_green bright_yellow
                    bright_blue bright_magenta bright_cyan bright_white]
      expected.each do |name|
        expect(TUITD::Screenshot.send(:const_get, :ANSI_RGB)).to have_key(name)
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
  end
end
