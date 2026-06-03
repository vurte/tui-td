# frozen_string_literal: true

require "rspec/expectations"

# RSpec matchers for TUITD::State and TUITD::Driver objects.
#
# When given a State, matchers check immediately.
# When given a Driver, matchers auto-wait (up to 3 seconds) for the condition.
#
# Usage:
#   require "tui_td/matchers"
#
#   # Immediate check on State
#   state = TUITD::State.new(driver.state_data)
#   expect(state).to have_text("Welcome")
#
#   # Auto-wait on Driver
#   expect(driver).to have_text("Welcome")
#
module TUITD
  module Matchers
    AUTO_WAIT_TIMEOUT = 3

    def self.auto_wait(actual, timeout: AUTO_WAIT_TIMEOUT, &predicate)
      if actual.respond_to?(:wait_for)
        begin
          actual.wait_for(timeout: timeout, &predicate)
          true
        rescue TUITD::TimeoutError
          false
        end
      else
        predicate.call(actual)
      end
    end

    RSpec::Matchers.define :have_text do |expected|
      match do |actual|
        Matchers.auto_wait(actual) { |s| s.find_text(expected).any? }
      end

      description { "have text #{expected.inspect}" }
      failure_message { |_actual| "expected terminal to contain #{expected.inspect}" }
      failure_message_when_negated { |_actual| "expected terminal NOT to contain #{expected.inspect}" }
    end

    RSpec::Matchers.define :have_regex do |pattern|
      match do |actual|
        @regex = pattern.is_a?(Regexp) ? pattern : Regexp.new(pattern.to_s)
        Matchers.auto_wait(actual) { |s| s.find_text(@regex).any? }
      end

      description { "match regex #{pattern.inspect}" }
      failure_message { |_actual| "expected terminal to match #{pattern.inspect}" }
      failure_message_when_negated { |_actual| "expected terminal NOT to match #{pattern.inspect}" }
    end

    RSpec::Matchers.define :have_fg do |expected|
      chain(:at) do |row, col|
        @row = row
        @col = col
      end

      match do |actual|
        Matchers.auto_wait(actual) do |s|
          @actual = s.foreground_at(@row, @col)
          @actual == expected
        end
      end

      description { "have foreground #{expected.inspect} at [#{@row},#{@col}]" }
      failure_message do |_actual|
        "expected FG at [#{@row},#{@col}] to be #{expected.inspect}, but was #{@actual.inspect}"
      end
    end

    RSpec::Matchers.define :have_bg do |expected|
      chain(:at) do |row, col|
        @row = row
        @col = col
      end

      match do |actual|
        Matchers.auto_wait(actual) do |s|
          @actual = s.background_at(@row, @col)
          @actual == expected
        end
      end

      description { "have background #{expected.inspect} at [#{@row},#{@col}]" }
      failure_message do |_actual|
        "expected BG at [#{@row},#{@col}] to be #{expected.inspect}, but was #{@actual.inspect}"
      end
    end

    RSpec::Matchers.define :have_style do
      chain(:at) do |row, col|
        @row = row
        @col = col
      end
      chain(:with) { |expected| @expected = expected }

      match do |actual|
        @expected_style = @expected || {}
        Matchers.auto_wait(actual) do |s|
          @actual = s.style_at(@row, @col)
          @expected_style.all? { |k, v| @actual[k] == v }
        end
      end

      description do
        "have style #{@expected_style.inspect} at [#{@row},#{@col}]"
      end
      failure_message do |_actual|
        "expected style at [#{@row},#{@col}] to be #{@expected_style.inspect}, but was #{@actual.inspect}"
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
