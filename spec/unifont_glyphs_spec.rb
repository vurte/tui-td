# frozen_string_literal: true

require "spec_helper"

RSpec.describe TUITD::UnifontGlyphs do
  describe ".codepoints" do
    it "returns an array of codepoints" do
      cps = described_class.codepoints
      expect(cps).to be_an(Array)
      expect(cps).not_to be_empty
    end

    it "contains common Latin-1 Supplement codepoints" do
      expect(described_class.codepoints).to include(0x00E9) # é
      expect(described_class.codepoints).to include(0x00F6) # ö
      expect(described_class.codepoints).to include(0x00DF) # ß
    end

    it "contains all codepoints as Integers" do
      expect(described_class.codepoints).to all(be_an(Integer))
    end
  end

  describe ".rows" do
    it "returns 16 bytes for an 8-wide glyph" do
      rows = described_class.rows(0x00E9) # é
      expect(rows).to be_an(Array)
      expect(rows.length).to eq(16)
      expect(rows).to all(be_an(Integer))
      expect(rows).to all(be >= 0)
      expect(rows).to all(be <= 255)
    end

    it "returns nil for a missing codepoint" do
      expect(described_class.rows(0x10FFFF)).to be_nil
    end

    it "returns visible pixels for common glyphs" do
      glyphs = {
        "Greek alpha" => 0x03B1, # α
        "Cyrillic De" => 0x0414, # Д
        "Euro sign" => 0x20AC, # €
        "Right arrow" => 0x2192, # →
        "Sum sign" => 0x2211, # ∑
        "Box horizontal" => 0x2500, # ─
        "Music note" => 0x266A, # ♪
        "Turkish g" => 0x011F, # ğ
      }

      glyphs.each do |name, cp|
        rows = described_class.rows(cp)
        expect(rows).not_to be_nil, "Expected #{name} (U+#{cp.to_s(16).upcase}) to exist"
        non_zero = rows.count { |b| b > 0 }
        expect(non_zero).to be > 0, "Expected #{name} to have visible pixels"
      end
    end

    it "covers all major scripts" do
      scripts = {
        Greek: [0x03B1, 0x03B2, 0x03B3], # α β γ
        Cyrillic: [0x0414, 0x0416, 0x0418], # Д Ж И
        Arabic: [0x062D, 0x0628, 0x0627], # ح ب ا
        Turkish: [0x011F, 0x015F, 0x0131], # ğ ş ı
        Math: [0x2211, 0x222B, 0x221E], # ∑ ∫ ∞
        Arrows: [0x2190, 0x2191, 0x2192], # ← ↑ →
        Box: [0x2500, 0x2502, 0x250C], # ─ │ ┌
      }

      scripts.each do |script, codepoints|
        codepoints.each do |cp|
          expect(described_class.rows(cp)).not_to be_nil,
                                                  "Expected #{script} U+#{cp.to_s(16).upcase} to be covered"
        end
      end
    end

    it "returns no more than 16 bytes per glyph" do
      described_class.codepoints.first(100).each do |cp|
        rows = described_class.rows(cp)
        expect(rows.length).to be <= 16
      end
    end
  end

  describe "cache independence" do
    it "returns different data for different codepoints" do
      a_rows = described_class.rows(0x03B1) # α
      d_rows = described_class.rows(0x0414) # Д
      expect(a_rows).not_to eq(d_rows)
    end

    it "returns same data for repeated calls" do
      rows1 = described_class.rows(0x03B1)
      rows2 = described_class.rows(0x03B1)
      expect(rows1).to eq(rows2)
    end
  end
end
