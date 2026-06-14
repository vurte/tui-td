# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe TUITD::VideoRecorder do
  let(:driver) { instance_double(TUITD::Driver, state_data: sample_state) }

  let(:sample_state) do
    {
      size: { rows: 5, cols: 20 },
      cursor: { row: 0, col: 0 },
      rows: Array.new(5) do
        Array.new(20) { { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false } }
      end,
    }
  end

  describe ".available?" do
    it "returns a boolean" do
      expect(described_class.available?).to(satisfy { |v| [true, false].include?(v) })
    end
  end

  describe "#initialize" do
    context "when ffmpeg is not available" do
      before do
        allow(described_class).to receive(:available?).and_return(false)
      end

      it "raises an error" do
        expect { described_class.new("/tmp/test.mp4", driver: driver) }
          .to raise_error(TUITD::Error, /ffmpeg not found/)
      end
    end

    context "when ffmpeg is available" do
      before do
        allow(described_class).to receive(:available?).and_return(true)
      end

      it "sets the output path, framerate, codec, and quality" do
        recorder = described_class.new("/tmp/test.mp4", driver: driver, framerate: 60,
                                                        codec: "libx265", quality: "medium",)
        expect(recorder.output_path).to eq(File.expand_path("/tmp/test.mp4"))
        expect(recorder.framerate).to eq(60)
        expect(recorder.codec).to eq("libx265")
        expect(recorder.quality).to eq("medium")
      end

      it "uses defaults for framerate, codec, and quality" do
        recorder = described_class.new("/tmp/test.mp4", driver: driver)
        expect(recorder.framerate).to eq(30)
        expect(recorder.codec).to eq("libx264")
        expect(recorder.quality).to eq("high")
      end
    end
  end

  describe "#recording?" do
    before do
      allow(described_class).to receive(:available?).and_return(true)
    end

    it "returns false before start" do
      recorder = described_class.new("/tmp/test.mp4", driver: driver)
      expect(recorder.recording?).to be false
    end

    it "returns true after start", :ffmpeg do
      recorder = described_class.new("/tmp/test.mp4", driver: driver)
      recorder.start
      expect(recorder.recording?).to be true
      recorder.stop
    end
  end

  describe "#start and #stop", :ffmpeg do
    before do
      skip "ffmpeg not available" unless described_class.available?
    end

    it "creates a video file on stop" do
      path = "/tmp/tui_td_test_#{Process.pid}.mp4"
      recorder = described_class.new(path, driver: driver, framerate: 2)

      recorder.start
      sleep 0.5 # Let a couple frames capture
      result = recorder.stop

      expect(result).to eq(File.expand_path(path))
      expect(File.exist?(path)).to be true
      expect(File.size(path)).to be > 0
    ensure
      FileUtils.rm_f(path)
    end
  end

  describe "#stop when not recording" do
    before do
      allow(described_class).to receive(:available?).and_return(true)
    end

    it "returns nil" do
      recorder = described_class.new("/tmp/test.mp4", driver: driver)
      expect(recorder.stop).to be_nil
    end
  end

  describe "driver integration" do
    before do
      allow(described_class).to receive(:available?).and_return(true)
    end

    it "starts, checks status, and stops via driver methods" do
      real_driver = TUITD::Driver.new("echo hello", rows: 5, cols: 20, timeout: 5)
      real_driver.start
      real_driver.wait_for_exit

      path = "/tmp/tui_td_driver_test_#{Process.pid}.mp4"
      real_driver.start_recording(path, framerate: 2)
      expect(real_driver.recording?).to be true
      sleep 0.5
      result = real_driver.stop_recording
      expect(result).to eq(File.expand_path(path))

      real_driver.close
      expect(real_driver.recording?).to be false
    end
  end

  describe "error handling" do
    before do
      allow(described_class).to receive(:available?).and_return(true)
    end

    it "handles ffmpeg pipe errors gracefully" do
      recorder = described_class.new("/tmp/test_pipe_err.mp4", driver: driver, framerate: 60)
      # Simulate pipe close by stopping immediately
      recorder.start
      recorder.stop
      # Should not raise
      expect(recorder.recording?).to be false
    end

    it "handles stop when not recording (nil return path)" do
      recorder = described_class.new("/tmp/test_stop_idle.mp4", driver: driver)
      result = recorder.stop
      expect(result).to be_nil
    end

    it "handles double stop gracefully" do
      recorder = described_class.new("/tmp/test_double_stop.mp4", driver: driver)
      recorder.start
      recorder.stop
      result = recorder.stop
      expect(result).to be_nil
    end
  end
end
