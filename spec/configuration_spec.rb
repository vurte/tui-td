# frozen_string_literal: true

require "spec_helper"

RSpec.describe TUITD::Configuration do
  around do |example|
    example.run
  ensure
    TUITD.instance_variable_set(:@configuration, nil)
  end

  describe "defaults" do
    it "snapshot_dir is nil" do
      expect(TUITD.configuration.snapshot_dir).to be_nil
    end
  end

  describe "#update_snapshots?" do
    it "returns true when ENV is set to 1" do
      allow(ENV).to receive(:[]).with("UPDATE_SNAPSHOTS").and_return("1")
      expect(TUITD.configuration.update_snapshots?).to be true
    end

    it "returns true when ENV is set to true" do
      allow(ENV).to receive(:[]).with("UPDATE_SNAPSHOTS").and_return("true")
      expect(TUITD.configuration.update_snapshots?).to be true
    end

    it "returns false when ENV is unset or 0" do
      allow(ENV).to receive(:[]).with("UPDATE_SNAPSHOTS").and_return(nil)
      expect(TUITD.configuration.update_snapshots?).to be false
    end
  end

  describe "configure block" do
    it "sets snapshot_dir" do
      TUITD.configure { |c| c.snapshot_dir = "spec/my_snapshots" }
      expect(TUITD.configuration.snapshot_dir).to eq("spec/my_snapshots")
    end

    it "sets snapshot_dir to nil" do
      TUITD.configure { |c| c.snapshot_dir = nil }
      expect(TUITD.configuration.snapshot_dir).to be_nil
    end
  end
end
