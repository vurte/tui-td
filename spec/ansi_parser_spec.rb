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
  end
end
