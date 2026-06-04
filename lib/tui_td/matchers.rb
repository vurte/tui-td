# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength, Metrics/BlockLength, Layout/LineLength

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

    # Selector-based matchers — work with both State and Driver (auto-wait)

    RSpec::Matchers.define :have_button do |expected|
      match do |actual|
        Matchers.auto_wait(actual) do |s|
          Selector.new(s).button(text: expected)
        end
      end

      description { "have button #{expected.inspect}" }
      failure_message { |_actual| "expected terminal to have a button #{expected.inspect}" }
      failure_message_when_negated { |_actual| "expected terminal NOT to have a button #{expected.inspect}" }
    end

    RSpec::Matchers.define :have_dialog do
      match do |actual|
        Matchers.auto_wait(actual) { |s| Selector.new(s).dialogs.any? }
      end

      description { "have a dialog" }
      failure_message { |_actual| "expected terminal to have a dialog" }
      failure_message_when_negated { |_actual| "expected terminal NOT to have a dialog" }
    end

    RSpec::Matchers.define :have_checkbox do |expected|
      chain(:checked) { @checked = true }
      chain(:unchecked) { @checked = false }

      match do |actual|
        Matchers.auto_wait(actual) do |s|
          filters = { text: expected }
          filters[:checked] = @checked unless @checked.nil?
          Selector.new(s).checkbox(**filters)
        end
      end

      description do
        desc = "have checkbox #{expected.inspect}"
        desc += " (checked)" if @checked == true
        desc += " (unchecked)" if @checked == false
        desc
      end
      failure_message do |_actual|
        desc = "expected terminal to have checkbox #{expected.inspect}"
        desc += " (checked)" if @checked == true
        desc += " (unchecked)" if @checked == false
        desc
      end
      failure_message_when_negated do |_actual|
        desc = "expected terminal NOT to have checkbox #{expected.inspect}"
        desc += " (checked)" if @checked == true
        desc += " (unchecked)" if @checked == false
        desc
      end
    end

    RSpec::Matchers.define :have_role do |role, text: nil, checked: nil, disabled: nil|
      match do |actual|
        Matchers.auto_wait(actual) do |s|
          filters = {}
          filters[:text] = text if text
          filters[:checked] = checked unless checked.nil?
          filters[:disabled] = disabled unless disabled.nil?
          Selector.new(s).get_by_role(role, **filters).any?
        end
      end

      description do
        desc = "have role :#{role}"
        desc += " with text #{text.inspect}" if text
        desc += " (checked)" if checked == true
        desc += " (disabled)" if disabled == true
        desc
      end
      failure_message do |_actual|
        desc = "expected terminal to have a :#{role}"
        desc += " with text #{text.inspect}" if text
        desc += " (checked)" if checked == true
        desc += " (disabled)" if disabled == true
        desc
      end
      failure_message_when_negated do |_actual|
        desc = "expected terminal NOT to have a :#{role}"
        desc += " with text #{text.inspect}" if text
        desc
      end
    end

    # New role matchers (tans-parser 0.1.2)

    RSpec::Matchers.define :have_input do |expected = nil|
      match do |actual|
        Matchers.auto_wait(actual) do |s|
          if expected
            Selector.new(s).input(text: expected)
          else
            Selector.new(s).inputs.any?
          end
        end
      end

      description do
        expected ? "have input #{expected.inspect}" : "have an input field"
      end
      failure_message do |_actual|
        expected ? "expected terminal to have an input #{expected.inspect}" : "expected terminal to have an input field"
      end
      failure_message_when_negated do |_actual|
        expected ? "expected terminal NOT to have an input #{expected.inspect}" : "expected terminal NOT to have an input field"
      end
    end

    RSpec::Matchers.define :have_label do |expected = nil|
      match do |actual|
        Matchers.auto_wait(actual) do |s|
          if expected
            Selector.new(s).label(text: expected)
          else
            Selector.new(s).labels.any?
          end
        end
      end

      description do
        expected ? "have label #{expected.inspect}" : "have a label"
      end
      failure_message do |_actual|
        expected ? "expected terminal to have a label #{expected.inspect}" : "expected terminal to have a label"
      end
      failure_message_when_negated do |_actual|
        expected ? "expected terminal NOT to have a label #{expected.inspect}" : "expected terminal NOT to have a label"
      end
    end

    RSpec::Matchers.define :have_menu do |expected = nil|
      match do |actual|
        Matchers.auto_wait(actual) do |s|
          if expected
            Selector.new(s).menu(text: expected)
          else
            Selector.new(s).menus.any?
          end
        end
      end

      description do
        expected ? "have menu #{expected.inspect}" : "have a menu"
      end
      failure_message do |_actual|
        expected ? "expected terminal to have a menu #{expected.inspect}" : "expected terminal to have a menu"
      end
      failure_message_when_negated do |_actual|
        expected ? "expected terminal NOT to have a menu #{expected.inspect}" : "expected terminal NOT to have a menu"
      end
    end

    RSpec::Matchers.define :have_tab do |expected = nil|
      match do |actual|
        Matchers.auto_wait(actual) do |s|
          if expected
            Selector.new(s).tab(text: expected)
          else
            Selector.new(s).tabs.any?
          end
        end
      end

      description do
        expected ? "have tab #{expected.inspect}" : "have a tab"
      end
      failure_message do |_actual|
        expected ? "expected terminal to have a tab #{expected.inspect}" : "expected terminal to have a tab"
      end
      failure_message_when_negated do |_actual|
        expected ? "expected terminal NOT to have a tab #{expected.inspect}" : "expected terminal NOT to have a tab"
      end
    end

    RSpec::Matchers.define :have_statusbar do |expected = nil|
      match do |actual|
        Matchers.auto_wait(actual) do |s|
          if expected
            Selector.new(s).statusbar(text: expected)
          else
            Selector.new(s).statusbars.any?
          end
        end
      end

      description do
        expected ? "have status bar #{expected.inspect}" : "have a status bar"
      end
      failure_message do |_actual|
        expected ? "expected terminal to have a status bar #{expected.inspect}" : "expected terminal to have a status bar"
      end
      failure_message_when_negated do |_actual|
        expected ? "expected terminal NOT to have a status bar #{expected.inspect}" : "expected terminal NOT to have a status bar"
      end
    end

    RSpec::Matchers.define :have_progress_bar do |expected = nil|
      match do |actual|
        Matchers.auto_wait(actual) do |s|
          if expected
            Selector.new(s).progress_bar(text: expected)
          else
            Selector.new(s).progress_bars.any?
          end
        end
      end

      description do
        expected ? "have progress bar #{expected.inspect}" : "have a progress bar"
      end
      failure_message do |_actual|
        expected ? "expected terminal to have a progress bar #{expected.inspect}" : "expected terminal to have a progress bar"
      end
      failure_message_when_negated do |_actual|
        expected ? "expected terminal NOT to have a progress bar #{expected.inspect}" : "expected terminal NOT to have a progress bar"
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength, Metrics/BlockLength, Layout/LineLength
