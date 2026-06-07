# frozen_string_literal: true

# rubocop:disable Style/OneClassPerFile
# Error must be defined before requires so sub-files can reference it
module TUITD
  class Error < StandardError; end
end

# The convenience method below reopens the module after requires, intentional for bootstrapping.

require_relative "tui_td/version"
require_relative "tui_td/driver"
require_relative "tui_td/ansi_parser"
require_relative "tui_td/ansi_utils"
require_relative "tui_td/state"
require_relative "tui_td/configuration"
require_relative "tui_td/snapshot"
require_relative "tui_td/screenshot"
require_relative "tui_td/video_recorder"
require_relative "tui_td/html_renderer"
require_relative "tui_td/test_runner"
require_relative "tui_td/selector"
require_relative "tui_td/mcp/server"
require_relative "tui_td/cli"

module TUITD
  # Convenience method: start a TUI driver, capture initial state
  def self.drive(command, **)
    driver = Driver.new(command, **)
    driver.start
    driver
  end
end
# rubocop:enable Style/OneClassPerFile
