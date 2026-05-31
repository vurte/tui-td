# frozen_string_literal: true

require "spec_helper"

RSpec.describe TUITD do
  describe "tansu forwarders" do
    it "TUITD::ANSIParser is Tansu::ANSIParser" do
      expect(TUITD::ANSIParser).to be Tansu::ANSIParser
      result = TUITD::ANSIParser.parse("hello", 10, 40)
      expect(result[:rows][0][0][:char]).to eq("h")
    end

    it "TUITD::State creates a Tansu::State" do
      data = {
        size: { rows: 1, cols: 1 },
        rows: [[{ char: "X", fg: "default", bg: "default", bold: false, italic: false, underline: false }]],
      }
      state = TUITD::State.new(data)
      expect(state).to be_a Tansu::State
      expect(state.rows).to eq(1)
    end

    it "TUITD::ANSIUtils constants match Tansu" do
      expect(TUITD::ANSIUtils::ANSI_RGB).to eq Tansu::ANSIUtils::ANSI_RGB
      expect(TUITD::ANSIUtils::CUBE).to eq Tansu::ANSIUtils::CUBE
      expect(TUITD::ANSIUtils::DEFAULT_FG).to eq Tansu::ANSIUtils::DEFAULT_FG
      expect(TUITD::ANSIUtils::DEFAULT_BG).to eq Tansu::ANSIUtils::DEFAULT_BG
    end
  end
end
