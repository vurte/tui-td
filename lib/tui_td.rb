# frozen_string_literal: true

module TUITD
  class Error < StandardError; end
end

require_relative "tui_td/version"
require_relative "tui_td/driver"
require_relative "tui_td/ansi_parser"
require_relative "tui_td/ansi_utils"
require_relative "tui_td/state"
require_relative "tui_td/screenshot"
require_relative "tui_td/html_renderer"
require_relative "tui_td/test_runner"
require_relative "tui_td/mcp/server"
require_relative "tui_td/cli"

module TUITD

  # Convenience method: start a TUI driver, capture initial state
  def self.drive(command, **opts)
    driver = Driver.new(command, **opts)
    driver.start
    driver
  end
end
