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

    it "TUITD::Selector delegates to TansParser::Selector" do
      state = TUITD::State.new({
                                 size: { rows: 3, cols: 20 },
                                 rows: 3.times.map do
                                   20.times.map do
                                     { char: " ", fg: "default", bg: "default", bold: false, italic: false,
                                       underline: false, }
                                   end
                                 end,
                               })
      selector = TUITD::Selector.new(state)
      expect(selector).to be_a TansParser::Selector
      elements = selector.get_by_role(:button)
      expect(elements).to be_an(Array)
    end

    it "TUITD::Element is TansParser::Element" do
      expect(TUITD::Element).to equal(TansParser::Element)
    end

    it "TUITD.drive convenience method starts a driver" do
      driver = described_class.drive("echo hello", rows: 5, cols: 30, timeout: 5)
      expect(driver).to be_a TUITD::Driver
      driver.wait_for_exit
      state = driver.state
      expect(state[:rows].flatten.map { |c| c[:char] }.join).to include("hello")
    ensure
      driver&.close
    end
  end
end
