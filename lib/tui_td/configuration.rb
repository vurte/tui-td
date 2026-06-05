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
    attr_accessor :snapshot_dir

    def initialize
      @snapshot_dir = nil
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
