# frozen_string_literal: true

# rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists, Metrics/ModuleLength

require "minitest"

module TUITD
  module Minitest
    # Assertions for TUI testing with Minitest.
    #
    # Include this module in your Minitest test class:
    #
    #   require "tui_td/minitest/assertions"
    #
    #   class MyTUITest < Minitest::Test
    #     include TUITD::Minitest::Assertions
    #
    #     def test_login_screen
    #       driver = TUITD::Driver.new("my_tui", rows: 24, cols: 80)
    #       driver.start
    #       assert_text(driver, "Welcome")
    #       assert_button(driver, "OK")
    #       refute_text(driver, "Error")
    #     ensure
    #       driver&.close
    #     end
    #   end
    #
    # Auto-wait: When given a Driver, assertions wait up to 3 seconds.
    # When given a State, assertions check immediately.
    #
    module Assertions
      AUTO_WAIT_TIMEOUT = 3

      private

      def auto_wait(actual, timeout: AUTO_WAIT_TIMEOUT, &predicate)
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

      def state_from(actual)
        if actual.respond_to?(:state_data)
          TUITD::State.new(actual.state_data)
        else
          actual # State or raw hash — pass through
        end
      end

      public

      # --- Text / Regex / Color / Style ---

      def assert_text(actual, expected)
        result = auto_wait(actual) { |s| s.find_text(expected).any? }
        assert(result, "Expected terminal to contain #{expected.inspect}")
      end

      def refute_text(actual, expected)
        result = auto_wait(actual) { |s| s.find_text(expected).empty? }
        assert(result, "Expected terminal NOT to contain #{expected.inspect}")
      end

      def assert_regex(actual, pattern)
        regex = pattern.is_a?(Regexp) ? pattern : Regexp.new(pattern.to_s)
        result = auto_wait(actual) { |s| s.find_text(regex).any? }
        assert(result, "Expected terminal to match #{pattern.inspect}")
      end

      def refute_regex(actual, pattern)
        regex = pattern.is_a?(Regexp) ? pattern : Regexp.new(pattern.to_s)
        result = auto_wait(actual) { |s| s.find_text(regex).empty? }
        assert(result, "Expected terminal NOT to match #{pattern.inspect}")
      end

      def assert_fg(actual, expected, row:, col:)
        result = auto_wait(actual) { |s| s.foreground_at(row, col) == expected }
        actual_fg = state_from(actual).foreground_at(row, col)
        assert(result, "Expected FG at [#{row},#{col}] to be #{expected.inspect}, but was #{actual_fg.inspect}")
      end

      def assert_bg(actual, expected, row:, col:)
        result = auto_wait(actual) { |s| s.background_at(row, col) == expected }
        actual_bg = state_from(actual).background_at(row, col)
        assert(result, "Expected BG at [#{row},#{col}] to be #{expected.inspect}, but was #{actual_bg.inspect}")
      end

      def assert_style(actual, row:, col:, **expected_styles)
        result = auto_wait(actual) do |s|
          style = s.style_at(row, col)
          expected_styles.all? { |k, v| style[k] == v }
        end
        actual_style = state_from(actual).style_at(row, col)
        assert(result,
               "Expected style at [#{row},#{col}] to be #{expected_styles.inspect}, but was #{actual_style.inspect}",)
      end

      def assert_exit_status(actual, expected)
        status = actual.exitstatus
        assert(status == expected, "Expected exit status #{expected}, but was #{status}")
      end

      # --- Selector-based ---

      def assert_button(actual, expected, min_confidence: nil)
        result = auto_wait(actual) do |s|
          el = TUITD::Selector.new(s).button(text: expected)
          if min_confidence && el
            el.confidence && el.confidence >= min_confidence
          else
            el
          end
        end
        msg = "Expected terminal to have a button #{expected.inspect}"
        msg += " (min_confidence: #{min_confidence})" if min_confidence
        assert(result, msg)
      end

      def refute_button(actual, expected)
        result = auto_wait(actual) { |s| TUITD::Selector.new(s).button(text: expected).nil? }
        assert(result, "Expected terminal NOT to have a button #{expected.inspect}")
      end

      def assert_dialog(actual, min_confidence: nil)
        result = auto_wait(actual) do |s|
          elements = TUITD::Selector.new(s).dialogs
          min_confidence ? elements.any? { |e| e.confidence && e.confidence >= min_confidence } : elements.any?
        end
        msg = "Expected terminal to have a dialog"
        msg += " (min_confidence: #{min_confidence})" if min_confidence
        assert(result, msg)
      end

      def refute_dialog(actual)
        result = auto_wait(actual) { |s| TUITD::Selector.new(s).dialogs.empty? }
        assert(result, "Expected terminal NOT to have a dialog")
      end

      def assert_checkbox(actual, expected, checked: nil, unchecked: nil, min_confidence: nil)
        checked = false if unchecked
        result = auto_wait(actual) do |s|
          filters = { text: expected }
          filters[:checked] = checked unless checked.nil?
          el = TUITD::Selector.new(s).checkbox(**filters)
          if min_confidence && el
            el.confidence && el.confidence >= min_confidence
          else
            el
          end
        end
        msg = "Expected terminal to have checkbox #{expected.inspect}"
        msg += " (checked)" if checked == true
        msg += " (unchecked)" if checked == false
        msg += " (min_confidence: #{min_confidence})" if min_confidence
        assert(result, msg)
      end

      def assert_role(actual, role, text: nil, checked: nil, disabled: nil, min_confidence: nil)
        result = auto_wait(actual) do |s|
          filters = {}
          filters[:text] = text if text
          filters[:checked] = checked unless checked.nil?
          filters[:disabled] = disabled unless disabled.nil?
          elements = TUITD::Selector.new(s).get_by_role(role, **filters)
          if min_confidence
            elements.any? { |e| e.confidence && e.confidence >= min_confidence }
          else
            elements.any?
          end
        end
        msg = "Expected terminal to have role :#{role}"
        msg += " with text #{text.inspect}" if text
        msg += " (min_confidence: #{min_confidence})" if min_confidence
        assert(result, msg)
      end

      def assert_input(actual, expected = nil, min_confidence: nil)
        result = auto_wait(actual) do |s|
          sel = TUITD::Selector.new(s)
          if expected
            el = sel.input(text: expected)
            min_confidence ? (el&.confidence && el.confidence >= min_confidence) : el
          else
            elements = sel.inputs
            min_confidence ? elements.any? { |e| e.confidence && e.confidence >= min_confidence } : elements.any?
          end
        end
        msg = "Expected terminal to have an input field"
        msg += " #{expected.inspect}" if expected
        msg += " (min_confidence: #{min_confidence})" if min_confidence
        assert(result, msg)
      end

      def assert_label(actual, expected = nil, min_confidence: nil)
        result = auto_wait(actual) do |s|
          sel = TUITD::Selector.new(s)
          elements = expected ? [sel.label(text: expected)].compact : sel.labels
          min_confidence ? elements.any? { |e| e.confidence && e.confidence >= min_confidence } : elements.any?
        end
        msg = "Expected terminal to have a label"
        msg += " #{expected.inspect}" if expected
        msg += " (min_confidence: #{min_confidence})" if min_confidence
        assert(result, msg)
      end

      def assert_menu(actual, expected = nil, min_confidence: nil)
        result = auto_wait(actual) do |s|
          sel = TUITD::Selector.new(s)
          elements = expected ? [sel.menu(text: expected)].compact : sel.menus
          min_confidence ? elements.any? { |e| e.confidence && e.confidence >= min_confidence } : elements.any?
        end
        msg = "Expected terminal to have a menu"
        msg += " #{expected.inspect}" if expected
        msg += " (min_confidence: #{min_confidence})" if min_confidence
        assert(result, msg)
      end

      def assert_tab(actual, expected = nil, min_confidence: nil)
        result = auto_wait(actual) do |s|
          sel = TUITD::Selector.new(s)
          elements = expected ? [sel.tab(text: expected)].compact : sel.tabs
          min_confidence ? elements.any? { |e| e.confidence && e.confidence >= min_confidence } : elements.any?
        end
        msg = "Expected terminal to have a tab"
        msg += " #{expected.inspect}" if expected
        msg += " (min_confidence: #{min_confidence})" if min_confidence
        assert(result, msg)
      end

      def assert_statusbar(actual, expected = nil, min_confidence: nil)
        result = auto_wait(actual) do |s|
          sel = TUITD::Selector.new(s)
          elements = expected ? [sel.statusbar(text: expected)].compact : sel.statusbars
          min_confidence ? elements.any? { |e| e.confidence && e.confidence >= min_confidence } : elements.any?
        end
        msg = "Expected terminal to have a status bar"
        msg += " #{expected.inspect}" if expected
        msg += " (min_confidence: #{min_confidence})" if min_confidence
        assert(result, msg)
      end

      def assert_progress_bar(actual, expected = nil, min_confidence: nil)
        result = auto_wait(actual) do |s|
          sel = TUITD::Selector.new(s)
          if expected
            el = sel.progress_bar(text: expected)
            min_confidence ? (el&.confidence && el.confidence >= min_confidence) : el
          else
            elements = sel.progress_bars
            min_confidence ? elements.any? { |e| e.confidence && e.confidence >= min_confidence } : elements.any?
          end
        end
        msg = "Expected terminal to have a progress bar"
        msg += " #{expected.inspect}" if expected
        msg += " (min_confidence: #{min_confidence})" if min_confidence
        assert(result, msg)
      end

      # --- Video Recording ---

      # Start recording the TUI session as a video (requires ffmpeg).
      # +actual+ must be a Driver.
      def assert_record_start(actual, path, framerate: 30, codec: "libx264", quality: "high")
        unless actual.respond_to?(:start_recording)
          raise ArgumentError, "assert_record_start requires a Driver, got #{actual.class}"
        end

        result = actual.start_recording(path, framerate: framerate, codec: codec, quality: quality)
        assert(result, "Recording failed to start")
      end

      # Stop video recording and finalize the video file.
      # +actual+ must be a Driver.
      def assert_record_stop(actual)
        unless actual.respond_to?(:stop_recording)
          raise ArgumentError, "assert_record_stop requires a Driver, got #{actual.class}"
        end

        path = actual.stop_recording
        assert(path, "No recording in progress")
      end

      # Verify that recording is currently active.
      def assert_recording(actual)
        unless actual.respond_to?(:recording?)
          raise ArgumentError, "assert_recording requires a Driver, got #{actual.class}"
        end

        assert(actual.recording?, "Expected recording to be active")
      end

      # Verify that recording is NOT active.
      def refute_recording(actual)
        unless actual.respond_to?(:recording?)
          raise ArgumentError, "refute_recording requires a Driver, got #{actual.class}"
        end

        refute(actual.recording?, "Expected recording NOT to be active")
      end

      # --- Snapshot ---

      def assert_snapshot(actual, name, type: :text, wait: false, region: nil, ignore_rows: nil)
        snap = TUITD::Snapshot.new(name.to_s, type: type)

        state_data = if actual.respond_to?(:state_data)
                       actual.wait_for_stable if wait && actual.respond_to?(:wait_for_stable)
                       actual.state_data
                     elsif actual.respond_to?(:to_h)
                       actual.to_h
                     else
                       actual
                     end

        if TUITD.configuration.update_snapshots? || !snap.exists?
          snap.save(state_data)
          pass
        else
          result = snap.compare(state_data, ignore_rows: ignore_rows, region: region)
          msg = result.passed? ? nil : "Snapshot '#{name}' does not match.\n#{result.message}"
          assert(result.passed?, msg)
        end
      end
    end
  end
end
# rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists, Metrics/ModuleLength
