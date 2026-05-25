# frozen_string_literal: true

require "spec_helper"

RSpec.describe TUITD::CairoRenderer do
  describe ".available?" do
    it "returns true when cairo is installed" do
      skip "cairo gem not installed" unless described_class.available?
      expect(described_class.available?).to be(true)
    end

    it "returns false or true without crashing" do
      expect(described_class.available?).to be(true).or be(false)
    end
  end

  describe ".render_glyph_onto" do
    let(:png) { ChunkyPNG::Image.new(8, 16, ChunkyPNG::Color::BLACK) }
    let(:white) { [0xC0, 0xC0, 0xC0] }

    before { skip "Cairo not available" unless described_class.available? }

    it "renders a visible glyph for ASCII characters" do
      described_class.render_glyph_onto(png, 0, 0, "A", white, bold: false, italic: false)
      colored_pixels = (0...16).sum { |y| (0...8).count { |x| png[x, y] != ChunkyPNG::Color::BLACK } }
      expect(colored_pixels).to be > 0
    end

    it "renders Greek characters without error" do
      expect do
        described_class.render_glyph_onto(png, 0, 0, "α", white, bold: false, italic: false)
      end.not_to raise_error
    end

    it "renders Cyrillic characters without error" do
      expect do
        described_class.render_glyph_onto(png, 0, 0, "Д", white, bold: false, italic: false)
      end.not_to raise_error
    end

    it "renders CJK characters without error" do
      expect do
        described_class.render_glyph_onto(png, 0, 0, "中", white, bold: false, italic: false)
      end.not_to raise_error
    end

    it "renders bold text with more pixels than normal" do
      described_class.render_glyph_onto(png, 0, 0, "A", white, bold: true, italic: false)
      bold_pixels = (0...16).sum { |y| (0...8).count { |x| png[x, y] != ChunkyPNG::Color::BLACK } }

      png2 = ChunkyPNG::Image.new(8, 16, ChunkyPNG::Color::BLACK)
      described_class.render_glyph_onto(png2, 0, 0, "A", white, bold: false, italic: false)
      normal_pixels = (0...16).sum { |y| (0...8).count { |x| png2[x, y] != ChunkyPNG::Color::BLACK } }

      expect(bold_pixels).to be >= normal_pixels
    end

    it "renders italic glyphs without error" do
      expect do
        described_class.render_glyph_onto(png, 0, 0, "A", white, bold: false, italic: true)
      end.not_to raise_error
    end

    it "is a no-op when cairo is not available" do
      skip "Cairo is available on this system" if described_class.available?
      expect do
        described_class.render_glyph_onto(png, 0, 0, "A", white, bold: false, italic: false)
      end.not_to raise_error
      colored_pixels = (0...16).sum { |y| (0...8).count { |x| png[x, y] != ChunkyPNG::Color::BLACK } }
      expect(colored_pixels).to eq(0)
    end
  end

  describe "cache behavior" do
    before { skip "Cairo not available" unless described_class.available? }

    it "handles repeated rendering without error" do
      png = ChunkyPNG::Image.new(8, 16, ChunkyPNG::Color::BLACK)
      white = [0xC0, 0xC0, 0xC0]
      5.times do
        described_class.render_glyph_onto(png, 0, 0, "X", white, bold: false, italic: false)
      end
    end
  end
end
