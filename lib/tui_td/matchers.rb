# frozen_string_literal: true

require "rspec/expectations"

# RSpec matchers for TUITD::State objects.
#
# Usage:
#   require "tui_td/matchers"
#
#   state = TUITD::State.new(driver.state_data)
#   expect(state).to have_text("Welcome")
#   expect(state).to have_fg("cyan").at(0, 0)
#
module TUITD
  module Matchers
    RSpec::Matchers.define :have_text do |expected|
      match do |state|
        state.find_text(expected).any?
      end

      description { "have text #{expected.inspect}" }
      failure_message { |_state| "expected terminal to contain #{expected.inspect}" }
      failure_message_when_negated { |_state| "expected terminal NOT to contain #{expected.inspect}" }
    end

    RSpec::Matchers.define :have_regex do |pattern|
      match do |state|
        @regex = pattern.is_a?(Regexp) ? pattern : Regexp.new(pattern.to_s)
        state.find_text(@regex).any?
      end

      description { "match regex #{pattern.inspect}" }
      failure_message { |_state| "expected terminal to match #{pattern.inspect}" }
      failure_message_when_negated { |_state| "expected terminal NOT to match #{pattern.inspect}" }
    end

    RSpec::Matchers.define :have_fg do |expected|
      chain(:at) do |row, col|
        @row = row
        @col = col
      end

      match do |state|
        @actual = state.foreground_at(@row, @col)
        @actual == expected
      end

      description { "have foreground #{expected.inspect} at [#{@row},#{@col}]" }
      failure_message do |_state|
        "expected FG at [#{@row},#{@col}] to be #{expected.inspect}, but was #{@actual.inspect}"
      end
    end

    RSpec::Matchers.define :have_bg do |expected|
      chain(:at) do |row, col|
        @row = row
        @col = col
      end

      match do |state|
        @actual = state.background_at(@row, @col)
        @actual == expected
      end

      description { "have background #{expected.inspect} at [#{@row},#{@col}]" }
      failure_message do |_state|
        "expected BG at [#{@row},#{@col}] to be #{expected.inspect}, but was #{@actual.inspect}"
      end
    end

    RSpec::Matchers.define :have_style do
      chain(:at) do |row, col|
        @row = row
        @col = col
      end
      chain(:with) { |expected| @expected = expected }

      match do |state|
        @actual = state.style_at(@row, @col)
        @expected ||= {}
        @expected.all? { |k, v| @actual[k] == v }
      end

      description do
        "have style #{@expected.inspect} at [#{@row},#{@col}]"
      end
      failure_message do |_state|
        "expected style at [#{@row},#{@col}] to be #{@expected.inspect}, but was #{@actual.inspect}"
      end
    end

    # Works on a Driver instance, not State
    RSpec::Matchers.define :have_exit_status do |expected|
      match do |driver|
        @actual = driver.exitstatus
        @actual == expected
      end

      description { "have exit status #{expected}" }
      failure_message do |_driver|
        "expected exit status #{expected}, but was #{@actual}"
      end
      failure_message_when_negated do |_driver|
        "expected exit status not to be #{expected}"
      end
    end
  end
end
