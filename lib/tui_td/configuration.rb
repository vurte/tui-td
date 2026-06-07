# frozen_string_literal: true

module TUITD
  # Global configuration for tui-td.
  #
  # Usage:
  #   TUITD.configure do |c|
  #     c.snapshot_dir = "spec/snapshots"
  #   end
  #
  class Configuration
    attr_accessor :snapshot_dir, :ffmpeg_path, :record_default_fps, :record_default_codec

    def initialize
      @snapshot_dir = nil
      @ffmpeg_path = nil
      @record_default_fps = 30
      @record_default_codec = "libx264"
    end

    # Check if UPDATE_SNAPSHOTS env var is set to update mode.
    def update_snapshots?
      %w[1 true].include?(ENV["UPDATE_SNAPSHOTS"].to_s)
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end
  end
end
