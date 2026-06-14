# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"

RSpec.describe TUITD::Snapshot do
  let(:snapshot_dir) { Dir.mktmpdir("tui_td_snapshot") }
  let(:state_data) do
    {
      size: { rows: 3, cols: 5 },
      cursor: { row: 0, col: 0, visible: false },
      rows: [
        [
          { char: "H", fg: "default", bg: "default", bold: false, italic: false, underline: false },
          { char: "e", fg: "default", bg: "default", bold: false, italic: false, underline: false },
          { char: "l", fg: "default", bg: "default", bold: false, italic: false, underline: false },
          { char: "l", fg: "default", bg: "default", bold: false, italic: false, underline: false },
          { char: "o", fg: "default", bg: "default", bold: false, italic: false, underline: false },
        ],
        Array.new(5) { { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false } },
        Array.new(5) { { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false } },
      ],
    }
  end
  let(:diff_state_data) do
    data = Marshal.load(Marshal.dump(state_data))
    data[:rows][0][0][:char] = "X"
    data
  end

  after { FileUtils.rm_rf(snapshot_dir) }

  describe "#new" do
    it "defaults to :text type" do
      snap = described_class.new("test", snapshot_dir: snapshot_dir)
      expect(snap.type).to eq(:text)
      expect(snap.name).to eq("test")
    end

    it "uses configured snapshot_dir when not given" do
      TUITD.configure { |c| c.snapshot_dir = snapshot_dir }
      snap = described_class.new("test")
      expect(snap.snapshot_dir).to eq(snapshot_dir)
    ensure
      TUITD.instance_variable_set(:@configuration, nil)
    end

    it "defaults to spec/snapshots when unconfigured" do
      TUITD.instance_variable_set(:@configuration, nil)
      snap = described_class.new("test")
      expect(snap.snapshot_dir).to eq("spec/snapshots")
    end
  end

  describe "#save" do
    it "saves .json for :text type" do
      snap = described_class.new("s1", type: :text, snapshot_dir: snapshot_dir)
      snap.save(state_data)
      expect(File).to exist(snap.path(".json"))
    end

    it "saves valid JSON for :text" do
      snap = described_class.new("json_test", type: :text, snapshot_dir: snapshot_dir)
      snap.save(state_data)
      parsed = JSON.parse(File.read(snap.path(".json")))
      expect(parsed).to have_key("rows")
      expect(parsed).to have_key("size")
    end

    it "saves .png for :png type" do
      snap = described_class.new("s2", type: :png, snapshot_dir: snapshot_dir)
      snap.save(state_data)
      expect(File).to exist(snap.path(".png"))
      expect(File.size(snap.path(".png"))).to be > 0
    end

    it "saves .html for :html type" do
      snap = described_class.new("s3", type: :html, snapshot_dir: snapshot_dir)
      snap.save(state_data)
      expect(File).to exist(snap.path(".html"))
      expect(File.read(snap.path(".html"))).to include("<!DOCTYPE html>")
    end

    it "saves all three for :all type" do
      snap = described_class.new("s4", type: :all, snapshot_dir: snapshot_dir)
      snap.save(state_data)
      expect(File).to exist(snap.path(".json"))
      expect(File).to exist(snap.path(".png"))
      expect(File).to exist(snap.path(".html"))
    end

    it "creates the snapshot directory if missing" do
      deep_dir = File.join(snapshot_dir, "nested", "dir")
      snap = described_class.new("test", snapshot_dir: deep_dir)
      snap.save(state_data)
      expect(Dir).to exist(deep_dir)
      expect(File).to exist(File.join(deep_dir, "test.json"))
    end
  end

  describe "#compare" do
    it "passes when states are identical (:text)" do
      snap = described_class.new("cmp", type: :text, snapshot_dir: snapshot_dir)
      snap.save(state_data)
      result = snap.compare(state_data)
      expect(result).to be_passed
      expect(result.diff_count).to eq(0)
    end

    it "fails when characters differ (:text)" do
      snap = described_class.new("cmp2", type: :text, snapshot_dir: snapshot_dir)
      snap.save(state_data)
      result = snap.compare(diff_state_data)
      expect(result).not_to be_passed
      expect(result.diff_count).to be > 0
    end

    it "passes when only style differs (:text ignores styles)" do
      snap = described_class.new("cmp3", type: :text, snapshot_dir: snapshot_dir)
      snap.save(state_data)
      style_data = Marshal.load(Marshal.dump(state_data))
      style_data[:rows][0][0][:bold] = true
      result = snap.compare(style_data)
      expect(result).to be_passed
    end

    it "fails when colors differ (:full detects colors)" do
      snap = described_class.new("cmp4", type: :full, snapshot_dir: snapshot_dir)
      snap.save(state_data)
      colored = Marshal.load(Marshal.dump(state_data))
      colored[:rows][0][0][:fg] = "red"
      result = snap.compare(colored)
      expect(result).not_to be_passed
    end

    it "handles missing snapshot file" do
      snap = described_class.new("nonexistent", type: :text, snapshot_dir: snapshot_dir)
      result = snap.compare(state_data)
      expect(result).not_to be_passed
      expect(result.message).to include("not found")
    end

    it "handles :png comparison" do
      snap = described_class.new("png_cmp", type: :png, snapshot_dir: snapshot_dir)
      snap.save(state_data)
      result = snap.compare(state_data)
      expect(result).to be_passed
    end

    it "handles :html comparison" do
      snap = described_class.new("html_cmp", type: :html, snapshot_dir: snapshot_dir)
      snap.save(state_data)
      result = snap.compare(state_data)
      expect(result).to be_passed
    end

    it "handles :all comparison" do
      snap = described_class.new("all_cmp", type: :all, snapshot_dir: snapshot_dir)
      snap.save(state_data)
      result = snap.compare(state_data)
      expect(result).to be_passed
    end

    it "respects region: filtering (only compares rows in region)" do
      snap = described_class.new("region1", type: :text, snapshot_dir: snapshot_dir)
      snap.save(state_data)
      # Modify a row outside the region and inside the region
      modified = Marshal.load(Marshal.dump(state_data))
      modified[:rows][0][0][:char] = "Z" # inside region (row 0)
      modified[:rows][2][0][:char] = "Y" # outside region (row 2)
      result = snap.compare(modified, region: 0..1)
      expect(result).not_to be_passed
      expect(result.diff_count).to eq(1) # only row 0 diff, row 2 ignored
    end

    it "combines region: and ignore_rows:" do
      snap = described_class.new("region2", type: :text, snapshot_dir: snapshot_dir)
      snap.save(state_data)
      modified = Marshal.load(Marshal.dump(state_data))
      modified[:rows][0][0][:char] = "Z" # inside region row 0, but ignored
      modified[:rows][1][0][:char] = "Y" # inside region row 1, not ignored
      result = snap.compare(modified, region: 0..2, ignore_rows: [0])
      expect(result).not_to be_passed
      expect(result.diff_count).to eq(1) # only row 1
    end
  end

  describe "#exists?" do
    it "returns false before save, true after" do
      snap = described_class.new("exist_test", type: :text, snapshot_dir: snapshot_dir)
      expect(snap.exists?).to be false
      snap.save(state_data)
      expect(snap.exists?).to be true
    end

    it "returns false for missing snapshot" do
      snap = described_class.new("missing", type: :text, snapshot_dir: snapshot_dir)
      expect(snap.exists?).to be false
    end

    it "returns true for :all type only when all formats exist" do
      snap = described_class.new("all_exist", type: :all, snapshot_dir: snapshot_dir)
      expect(snap.exists?).to be false
      # Save only json — still false because png and html missing
      snap.save(state_data)
      expect(snap.exists?).to be true
    end

    it "returns false for :all type when one format missing" do
      snap = described_class.new("all_partial", type: :all, snapshot_dir: snapshot_dir)
      # Manually create only json, missing png/html
      File.write(snap.path(".json"), "{}")
      expect(snap.exists?).to be false
    end
  end

  describe "#compare edge cases" do
    it "handles JSON parse error in saved snapshot" do
      snap = described_class.new("corrupt", type: :text, snapshot_dir: snapshot_dir)
      File.write(snap.path(".json"), "NOT VALID JSON!!!")
      result = snap.compare(state_data)
      expect(result).not_to be_passed
      expect(result.message).to include("Failed to parse snapshot JSON")
    end

    it "handles normalize with string-keyed state data" do
      snap = described_class.new("raw_hash", type: :text, snapshot_dir: snapshot_dir)
      raw_data = { size: { rows: 1, cols: 1 },
                   rows: [[{ char: "X", fg: "default", bg: "default", bold: false, italic: false,
                             underline: false, }]], }
      snap.save(raw_data)
      result = snap.compare(raw_data)
      expect(result).to be_passed
    end

    it "handles compare with region as Array" do
      snap = described_class.new("arr_region", type: :text, snapshot_dir: snapshot_dir)
      snap.save(state_data)
      modified = Marshal.load(Marshal.dump(state_data))
      modified[:rows][0][0][:char] = "Z"
      result = snap.compare(modified, region: [0])
      expect(result).not_to be_passed
      expect(result.diff_count).to eq(1)
    end

    it "handles png comparison mismatch" do
      snap = described_class.new("png_mismatch", type: :png, snapshot_dir: snapshot_dir)
      snap.save(state_data)
      # Modify state to produce different png
      modified = Marshal.load(Marshal.dump(state_data))
      modified[:rows][0][0][:fg] = "red"
      result = snap.compare(modified)
      expect(result).not_to be_passed
      expect(result.message).to include("does not match")
    end

    it "handles html comparison mismatch" do
      snap = described_class.new("html_mismatch", type: :html, snapshot_dir: snapshot_dir)
      snap.save(state_data)
      modified = Marshal.load(Marshal.dump(state_data))
      modified[:rows][0][0][:char] = "Z"
      result = snap.compare(modified)
      expect(result).not_to be_passed
      expect(result.message).to include("does not match")
    end

    it "handles normalize with a state-like object (responds to grid/rows)" do
      snap = described_class.new("state_obj", type: :text, snapshot_dir: snapshot_dir)
      obj = double("state", grid: state_data[:rows], rows: state_data[:size][:rows],
                            cols: state_data[:size][:cols], cursor: { row: 0, col: 0 },)
      snap.save(obj)
      expect(File).to exist(snap.path(".json"))
      result = snap.compare(obj)
      expect(result).to be_passed
    end

    it "handles normalize fallback for non-hash non-state objects" do
      snap = described_class.new("fallback_obj", type: :text, snapshot_dir: snapshot_dir)
      snap.save(state_data) # Create valid snapshot file
      weird_obj = Object.new
      expect { snap.compare(weird_obj) }.to raise_error(NoMethodError)
    end
  end
end
