# frozen_string_literal: true

require "spec_helper"

RSpec.describe TUITD::ANSIParser do
  describe ".parse" do
    it "handles plain text" do
      state = described_class.parse("hello world", 10, 40)
      expect(state[:rows][0][0..4].map { |c| c[:char] }.join).to eq("hello")
      expect(state[:cursor][:row]).to eq(0)
      expect(state[:cursor][:col]).to eq(11)
    end

    it "handles line feeds" do
      state = described_class.parse("hello\nworld", 10, 40)
      expect(state[:rows][0][0..4].map { |c| c[:char] }.join).to eq("hello")
      expect(state[:rows][1][0..4].map { |c| c[:char] }.join).to eq("world")
    end

    it "handles carriage returns" do
      state = described_class.parse("hello\rworld", 10, 40)
      expect(state[:rows][0][0..4].map { |c| c[:char] }.join).to eq("world")
    end

    it "handles SGR color codes" do
      state = described_class.parse("\e[31mred\e[0mnormal", 10, 40)
      expect(state[:rows][0][0][:fg]).to eq("red")
      expect(state[:rows][0][0][:char]).to eq("r")
      expect(state[:rows][0][3][:fg]).to eq("default")
    end

    it "handles bold" do
      state = described_class.parse("\e[1mbold text\e[0m", 10, 40)
      expect(state[:rows][0][0][:bold]).to be true
      expect(state[:rows][0][5][:bold]).to be true
    end

    it "handles cursor movements" do
      state = described_class.parse("AB\e[2DC", 10, 40)
      # 1. Write A at (0,0), B at (0,1)
      # 2. Cursor back 2 → (0,0)
      # 3. Write C at (0,0) → overwrites A
      expect(state[:rows][0][0][:char]).to eq("C")
      expect(state[:rows][0][1][:char]).to eq("B")
    end

    it "handles erasing in display" do
      state = described_class.parse("first_line\nsecond_line\e[2Jnew", 10, 40)
      # After erase entire display, only "new" should remain visible
      expect(state[:rows][0][0..2].map { |c| c[:char] }.join).to eq("new")
    end

    it "handles ANSI 256-color codes" do
      state = described_class.parse("\e[38;5;82mgreenish\e[0m", 10, 40)
      expect(state[:rows][0][0][:fg]).to eq("color82")
    end

    it "handles ANSI truecolor codes" do
      state = described_class.parse("\e[38;2;255;100;50mcustom\e[0m", 10, 40)
      expect(state[:rows][0][0][:fg]).to eq("#ff6432")
    end

    it "handles scrolling overflow" do
      # Fill more lines than the screen height
      state = described_class.parse((1..15).map { |i| "line_#{i}" }.join("\n"), 10, 40)
      # Only the last 10 lines should be visible
      text = state[:rows].map { |r| r.map { |c| c[:char] }.join.strip }.reject(&:empty?)
      expect(text.first).to eq("line_6")
      expect(text.last).to eq("line_15")
    end

    it "handles cursor jump to large row safely" do
      # CUP to row 200 in a 10-row terminal — should clamp without error
      state = described_class.parse("\e[200;1Hcontent", 10, 40)
      expect(state[:cursor][:row]).to eq(9)
      expect(state[:rows].length).to eq(10)
      expect(state[:rows][9].map { |c| c[:char] }.join).to start_with("content")
    end

    it "scrolls efficiently with many newlines" do
      # 100 newlines in a 10-row terminal — should not error
      input = "first\n" + ("\n" * 100) + "last"
      state = described_class.parse(input, 10, 40)
      expect(state[:rows].length).to eq(10)
      line = state[:rows][9].map { |c| c[:char] }.join
      expect(line).to include("last")
    end

    it "handles tabs" do
      state = described_class.parse("a\tb", 10, 40)
      expect(state[:rows][0][0][:char]).to eq("a")
      expect(state[:rows][0][8][:char]).to eq("b")
    end

    it "skips ISO 2022 charset sequences like \e(B" do
      state = described_class.parse("\e(Bhello\e(B world", 10, 40)
      line = state[:rows][0].map { |c| c[:char] }.join
      expect(line).to start_with("hello world")
    end

    it "detects DSR (Device Status Report) request" do
      state = described_class.parse("\e[6n", 10, 40)
      expect(state[:pending_dsr]).to be true
    end

    it "sets pending_dsr to false when no DSR request" do
      state = described_class.parse("hello world", 10, 40)
      expect(state[:pending_dsr]).to be false
    end

    it "skips DEC private mode set sequences like \\e[?25h" do
      # Cursor visibility toggle should not leak chars into output
      state = described_class.parse("hello\e[?25hworld", 10, 40)
      line = state[:rows][0].map { |c| c[:char] }.join
      expect(line).to start_with("helloworld")
    end

    it "skips DEC private mode reset sequences like \\e[?25l" do
      state = described_class.parse("before\e[?25lafter", 10, 40)
      line = state[:rows][0].map { |c| c[:char] }.join
      expect(line).to start_with("beforeafter")
    end

    it "skips alternate screen buffer \\e[?1049h" do
      state = described_class.parse("vim\e[?1049hcontent", 10, 40)
      line = state[:rows][0].map { |c| c[:char] }.join
      expect(line).to start_with("vimcontent")
    end

    it "skips alternate screen buffer exit \\e[?1049l" do
      state = described_class.parse("leaving\e[?1049lback", 10, 40)
      line = state[:rows][0].map { |c| c[:char] }.join
      expect(line).to start_with("leavingback")
    end

    # ---- Cursor movement ----

    it "handles CUU (cursor up)" do
      state = described_class.parse("line1\nline2\e[AX", 10, 40)
      # After writing line1, newline, line2: cursor at row 1, col 5
      # CUU 1: cursor moves to row 0, col 5; X overwrites position 5
      expect(state[:rows][0][5][:char]).to eq("X")
    end

    it "handles CUD (cursor down)" do
      state = described_class.parse("\e[2BX", 10, 40)
      # Cursor down 2 from row 0 → row 2
      expect(state[:rows][2][0][:char]).to eq("X")
    end

    it "handles CUF (cursor forward)" do
      state = described_class.parse("A\e[2CB", 10, 40)
      expect(state[:rows][0][0][:char]).to eq("A")
      # After A at col 0, CUF 2 moves cursor to col 3
      expect(state[:rows][0][3][:char]).to eq("B")
    end

    it "handles backspace" do
      state = described_class.parse("AB\bC", 10, 40)
      expect(state[:rows][0][0][:char]).to eq("A")
      expect(state[:rows][0][1][:char]).to eq("C")
    end

    # ---- SGR variants ----

    it "handles SGR background color" do
      state = described_class.parse("\e[41mbg red\e[0m", 10, 40)
      expect(state[:rows][0][0][:bg]).to eq("red")
    end

    it "handles SGR bright foreground" do
      state = described_class.parse("\e[91mbright red\e[0m", 10, 40)
      expect(state[:rows][0][0][:fg]).to eq("bright_red")
    end

    it "handles SGR bright background" do
      state = described_class.parse("\e[101mbg bright red\e[0m", 10, 40)
      expect(state[:rows][0][0][:bg]).to eq("bright_red")
    end

    it "handles SGR normal (22) turning off bold" do
      state = described_class.parse("\e[1mbold\e[22m normal", 10, 40)
      expect(state[:rows][0][0][:bold]).to be true
      # Characters after \e[22m should not be bold
      expect(state[:rows][0][5][:bold]).to be false
    end

    it "handles SGR normal (23) turning off italic" do
      state = described_class.parse("\e[3mitalic\e[23m normal", 10, 40)
      expect(state[:rows][0][0][:italic]).to be true
      expect(state[:rows][0][7][:italic]).to be false
    end

    it "handles SGR normal (24) turning off underline" do
      state = described_class.parse("\e[4mul\e[24m normal", 10, 40)
      expect(state[:rows][0][0][:underline]).to be true
      expect(state[:rows][0][3][:underline]).to be false
    end

    it "handles SGR reverse video (7)" do
      state = described_class.parse("\e[31;44m\e[7mrev\e[0m", 10, 40)
      # After reverse, fg and bg are swapped
      expect(state[:rows][0][0][:fg]).to eq("blue")
      expect(state[:rows][0][0][:bg]).to eq("red")
    end

    it "handles SGR blink (5) as no-op" do
      state = described_class.parse("\e[5mblink\e[0m", 10, 40)
      expect(state[:rows][0][0][:char]).to eq("b")
    end

    # ---- Erase variants ----

    it "handles ED erase-down (0)" do
      state = described_class.parse("AAAA\nBBBB\nCCCC\e[H\e[0J", 10, 40)
      # Move cursor to home (0,0) with CUP, then erase down
      # Erases from cursor to end of screen
      expect(state[:rows][0][0][:char]).to eq(" ")
      expect(state[:rows][1][0][:char]).to eq(" ")
      expect(state[:rows][2][0][:char]).to eq(" ")
    end

    it "handles ED erase-up (1)" do
      state = described_class.parse("AAAA\nBBBB\e[2A\e[1J", 10, 40)
      # Move to row 0 (CUU 2 from row 2), then erase from start to cursor
      expect(state[:rows][0][0][:char]).to eq(" ")
      expect(state[:rows][1][0][:char]).to eq("B")
    end

    it "handles EL erase-right (0)" do
      state = described_class.parse("ABCD\e[2D\e[0K", 10, 40)
      # Cursor back 2 to position 2 ('C'), erase to end of line
      expect(state[:rows][0][0][:char]).to eq("A")
      expect(state[:rows][0][1][:char]).to eq("B")
      expect(state[:rows][0][2][:char]).to eq(" ")
    end

    it "handles EL erase-left (1)" do
      state = described_class.parse("ABCD\e[1K", 10, 40)
      # Erase from start to cursor (col 4)
      expect(state[:rows][0][0][:char]).to eq(" ")
    end

    it "handles EL erase-line (2)" do
      state = described_class.parse("ABCD\e[2K", 10, 40)
      expect(state[:rows][0][0][:char]).to eq(" ")
    end

    it "handles Erase Characters (X)" do
      state = described_class.parse("ABCD\e[2D\e[2X", 10, 40)
      # Cursor back 2 to 'C', erase 2 chars
      expect(state[:rows][0][0][:char]).to eq("A")
      expect(state[:rows][0][1][:char]).to eq("B")
      expect(state[:rows][0][2][:char]).to eq(" ")
      expect(state[:rows][0][3][:char]).to eq(" ")
    end

    # ---- Multi-byte UTF-8 ----

    it "handles multi-byte UTF-8 characters" do
      state = described_class.parse("café", 10, 40)
      line = state[:rows][0].map { |c| c[:char] }.join.strip
      expect(line).to eq("café")
    end

    it "handles emoji characters" do
      state = described_class.parse("hello 🌍", 10, 40)
      line = state[:rows][0].map { |c| c[:char] }.join.strip
      expect(line).to eq("hello 🌍")
    end

    # ---- DECSC / DECRC (Save / Restore Cursor) ----

    it "saves and restores cursor via ESC 7 / ESC 8" do
      state = described_class.parse("hello\e7world\e8X", 10, 40)
      # After "hello": cursor at (0,5)
      # ESC 7: save (0,5)
      # "world": cursor at (0,10)
      # ESC 8: restore to (0,5)
      # X overwrites position 5
      expect(state[:rows][0][5][:char]).to eq("X")
    end

    it "saves and restores cursor via CSI s / CSI u" do
      state = described_class.parse("hello\e[sworld\e[uX", 10, 40)
      # After "hello": cursor at (0,5)
      # CSI s: save (0,5)
      # "world": cursor at (0,10)
      # CSI u: restore to (0,5)
      # X overwrites position 5
      expect(state[:rows][0][5][:char]).to eq("X")
    end

    it "restore without prior save is a no-op" do
      state = described_class.parse("hello\e8X", 10, 40)
      # ESC 8 without prior save: cursor unchanged, X writes at next position
      expect(state[:rows][0][5][:char]).to eq("X")
    end

    # ---- DECSTBM (Set Scroll Region) ----

    it "scrolls within a defined scroll region" do
      # Fill content, then set scroll region to rows 4-7 (1-indexed)
      # Write more content to trigger scroll within the region
      input = (1..10).map { |i| "line#{i}" }.join("\n")
      input += "\e[4;7r"  # scroll region rows 4-7
      input += "\e[7;1H"  # move cursor to row 7
      input += "\nextra1\nextra2"
      state = described_class.parse(input, 10, 40)
      # Rows 0-2 (lines 1-3) should be unchanged
      expect(state[:rows][0].map { |c| c[:char] }.join.strip).to eq("line1")
      expect(state[:rows][1].map { |c| c[:char] }.join.strip).to eq("line2")
      expect(state[:rows][2].map { |c| c[:char] }.join.strip).to eq("line3")
      # Row 9 should still be line10 (outside scroll region)
      expect(state[:rows][9].map { |c| c[:char] }.join.strip).to eq("line10")
    end

    it "resets scroll region with \\e[r" do
      state = described_class.parse("line1\nline2\n\e[1;2r\e[r", 10, 40)
      # \e[1;2r sets scroll region to rows 1-2
      # \e[r resets to full screen
      expect(state[:cursor][:row]).to eq(0)
      expect(state[:cursor][:col]).to eq(0)
    end
  end

  describe ".build_frame" do
    it "reconstructs ANSI from empty state" do
      state = described_class.parse("", 3, 10)
      frame = described_class.build_frame(state)
      expect(frame).to start_with("\e[0m")
      expect(frame).to end_with("\e[0m")
    end

    it "round-trips plain text" do
      original = described_class.parse("hello world", 5, 40)
      frame = described_class.build_frame(original)
      round_tripped = described_class.parse(frame, 5, 40)
      expect(round_tripped[:rows][0].map { |c| c[:char] }.join.strip).to eq("hello world")
    end

    it "round-trips styled text" do
      original = described_class.parse("\e[31mred\e[1mbold red\e[0m normal", 5, 40)
      frame = described_class.build_frame(original)
      round_tripped = described_class.parse(frame, 5, 40)
      # Color names are converted to numeric codes by build_frame, so round-trip
      # produces color1 (256-color index for red) instead of "red"
      expect(round_tripped[:rows][0][0][:fg]).to eq("color1")
      expect(round_tripped[:rows][0][0][:char]).to eq("r")
    end

    it "build_frame handles string keys" do
      state = {
        "size" => { "rows" => 2, "cols" => 5 },
        "cursor" => { "row" => 0, "col" => 0 },
        "rows" => [
          [{ "char" => "S", "fg" => "green", "bg" => "default", "bold" => false, "italic" => false, "underline" => false }],
          [],
        ],
      }
      frame = described_class.build_frame(state)
      # green → 256-color index 2
      expect(frame).to include("38;5;2")
    end
  end

  describe "._color_code" do
    it "returns 256-color sequence for named ANSI colors" do
      code = described_class._color_code("red", "38")
      expect(code).to eq("38;5;1")
    end

    it "returns 256-color sequence for bright colors" do
      code = described_class._color_code("bright_red", "38")
      expect(code).to eq("38;5;9")
    end

    it "returns TrueColor sequence for hex colors" do
      code = described_class._color_code("#ff8800", "48")
      expect(code).to eq("48;2;255;136;0")
    end

    it "returns nil for default" do
      expect(described_class._color_code("default", "38")).to be_nil
    end
  end
end
