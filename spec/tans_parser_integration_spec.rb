# frozen_string_literal: true

require "spec_helper"

RSpec.describe TUITD do
  describe "tans-parser forwarders" do
    it "TUITD::ANSIParser is TansParser::ANSIParser" do
      expect(TUITD::ANSIParser).to be TansParser::ANSIParser
      result = TUITD::ANSIParser.parse("hello", 10, 40)
      expect(result[:rows][0][0][:char]).to eq("h")
    end

    it "TUITD::State creates a TansParser::State" do
      data = {
        size: { rows: 1, cols: 1 },
        rows: [[{ char: "X", fg: "default", bg: "default", bold: false, italic: false, underline: false }]],
      }
      state = TUITD::State.new(data)
      expect(state).to be_a TansParser::State
      expect(state.rows).to eq(1)
    end

    it "TUITD::ANSIUtils constants match TansParser" do
      expect(TUITD::ANSIUtils::ANSI_RGB).to eq TansParser::ANSIUtils::ANSI_RGB
      expect(TUITD::ANSIUtils::CUBE).to eq TansParser::ANSIUtils::CUBE
      expect(TUITD::ANSIUtils::DEFAULT_FG).to eq TansParser::ANSIUtils::DEFAULT_FG
      expect(TUITD::ANSIUtils::DEFAULT_BG).to eq TansParser::ANSIUtils::DEFAULT_BG
    end
  end
end
