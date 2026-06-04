# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/BlockLength, Metrics/ClassLength

require "json"
require "shellwords"

module TUITD
  # Executes TUI tests defined in JSON format.
  #
  #   plan = File.read("test/hello.json")
  #   results = TUITD::TestRunner.new(plan).run
  #   puts results[:passed]  # => true
  #
  # JSON format:
  #   {
  #     "name": "My test",
  #     "rows": 24, "cols": 80, "timeout": 10,
  #     "chdir": "/path/to/workdir",
  #     "before_all": [{"start": "my_tui", "env": {"FOO": "bar"}}],
  #     "steps": [
  #       {"wait_for_text": "> "},
  #       {"send": "hello\n"},
  #       {"assert_text": "hello"},
  #       {"assert_fg": [0, 0], "is": "cyan"}
  #     ],
  #     "after_all": [{"close": true}]
  #   }
  #
  # Per-step "timeout" overrides the top-level default:
  #   {"wait_for_text": "Slow", "timeout": 60}
  #
  class TestRunner
    Result = Struct.new(:step, :passed, :message, keyword_init: true)

    def initialize(source, on_step: nil)
      raw = source.is_a?(String) ? JSON.parse(source) : source
      @plan = raw.transform_keys(&:to_sym)
      @plan[:steps] = @plan[:steps].map { |s| s.transform_keys(&:to_sym) }
      @plan[:before_all] = @plan[:before_all]&.map { |s| s.transform_keys(&:to_sym) }
      @plan[:after_all] = @plan[:after_all]&.map { |s| s.transform_keys(&:to_sym) }
      @on_step = on_step
    rescue JSON::ParserError => e
      raise Error, "Invalid JSON: #{e.message}"
    end

    def run
      driver = nil
      rows = @plan[:rows] || 40
      cols = @plan[:cols] || 120
      timeout = @plan[:timeout] || 30
      chdir = @plan[:chdir]

      hooks = [
        { label: :before_all, steps: @plan[:before_all] || [] },
        { label: :main, steps: @plan[:steps] },
        { label: :after_all, steps: @plan[:after_all] || [] },
      ]

      all_results = []
      all_passed = true
      total_steps = hooks.sum { |p| p[:steps].size }

      hooks.each do |phase|
        phase[:steps].each do |step|
          action = step.keys.first.to_s
          value = step.values.first

          begin
            step_timeout = step[:timeout] || timeout
            r = case action
                when "start"
                  driver&.close
                  env = step[:env] || {}
                  env = env.transform_keys(&:to_sym).transform_values(&:to_s) if env.is_a?(Hash)
                  driver = Driver.new(value.to_s, rows: rows, cols: cols, timeout: step_timeout, chdir: chdir, env: env)
                  driver.start
                  Result.new(step: action, passed: true, message: "Started: #{value}")

                when "send"
                  ensure_driver!(driver)
                  driver.send(value.to_s)
                  Result.new(step: action, passed: true, message: "Sent #{value.to_s.length} characters")

                when "send_key"
                  ensure_driver!(driver)
                  driver.send_keys(value.to_s.to_sym)
                  Result.new(step: action, passed: true, message: "Sent key: #{value}")

                when "wait_for_text"
                  ensure_driver!(driver)
                  driver.wait_for_text(value.to_s)
                  Result.new(step: action, passed: true, message: "Found: #{value}")

                when "wait_for_stable"
                  ensure_driver!(driver)
                  driver.wait_for_stable
                  Result.new(step: action, passed: true, message: "Stable")

                when "assert_text", "assert_not_text", "assert_regex"
                  check_text(driver, value, action)

                when "assert_fg"
                  check_color(driver, step, :fg)

                when "assert_bg"
                  check_color(driver, step, :bg)

                when "assert_style"
                  ensure_driver!(driver)
                  row, col = coords(step)
                  expected_style = {}
                  expected_style[:bold] = step[:bold] unless step[:bold].nil?
                  expected_style[:italic] = step[:italic] unless step[:italic].nil?
                  expected_style[:underline] = step[:underline] unless step[:underline].nil?
                  actual = nil
                  match = begin
                    driver.wait_for(timeout: 2) do |s|
                      actual = s.style_at(row, col)
                      expected_style.all? { |k, v| actual[k] == v }
                    end
                    true
                  rescue TimeoutError
                    false
                  end
                  actual ||= begin
                    state = State.new(driver.state_data)
                    state.style_at(row, col)
                  end
                  if match
                    Result.new(step: action, passed: true,
                               message: "Style at [#{row},#{col}] matches #{expected_style}",)
                  else
                    Result.new(step: action, passed: false,
                               message: "Style at [#{row},#{col}] is #{actual}, expected #{expected_style}",)
                  end

                when "screenshot"
                  ensure_driver!(driver)
                  path = safe_output_path(value, "png")
                  driver.screenshot(path)
                  Result.new(step: action, passed: true, message: "Saved: #{path}")

                when "html"
                  ensure_driver!(driver)
                  path = safe_output_path(value, "html")
                  HtmlRenderer.new(driver.state_data).render(path)
                  Result.new(step: action, passed: true, message: "Saved: #{path}")

                when "wait_for_exit"
                  ensure_driver!(driver)
                  driver.wait_for_exit
                  status = driver.exitstatus
                  Result.new(step: action, passed: true, message: "Exited with status #{status}")

                when "assert_exit"
                  ensure_driver!(driver)
                  expected = value.to_s.to_i
                  actual = driver.exitstatus
                  if actual == expected
                    Result.new(step: action, passed: true, message: "Exit status #{expected} matches")
                  else
                    Result.new(step: action, passed: false, message: "Exit status #{actual}, expected #{expected}")
                  end

                when "assert_button"
                  check_role(driver, :button, value.to_s)

                when "assert_dialog"
                  check_role(driver, :dialog, nil)

                when "assert_checkbox"
                  check_role(driver, :checkbox, value.to_s, checked: step[:checked], disabled: step[:disabled])

                when "assert_role"
                  role = step[:role]&.to_sym
                  check_role(driver, role, value.to_s, checked: step[:checked], disabled: step[:disabled])

                when "assert_input"
                  check_role(driver, :input, value == true ? nil : value.to_s)

                when "assert_label"
                  check_role(driver, :label, value == true ? nil : value.to_s)

                when "assert_menu"
                  check_role(driver, :menu, value == true ? nil : value.to_s)

                when "assert_tab"
                  check_role(driver, :tab, value == true ? nil : value.to_s)

                when "assert_statusbar"
                  check_role(driver, :statusbar, value == true ? nil : value.to_s)

                when "assert_progress_bar"
                  check_role(driver, :progress, value == true ? nil : value.to_s)

                when "close"
                  driver&.close
                  driver = nil
                  Result.new(step: action, passed: true, message: "Closed")

                else
                  Result.new(step: action, passed: false, message: "Unknown action: #{action}")
                end
          rescue StandardError => e
            r = Result.new(step: action, passed: false, message: "#{e.class}: #{e.message}")
          end

          all_results << r
          all_passed &&= r.passed

          next unless @on_step

          state_data = nil
          begin
            state_data = driver.state_data if driver
          rescue StandardError
            # ignore — state retrieval is best-effort
          end
          @on_step.call(
            index: all_results.size - 1,
            total: total_steps,
            action: action,
            value: value,
            result: r,
            driver: driver,
            state_data: state_data,
          )
        end
      end

      driver&.close

      {
        name: @plan[:name] || "(unnamed)",
        passed: all_passed,
        results: all_results.map(&:to_h),
      }
    end

    ALLOWED_OUTPUT_DIRS = ["/tmp"].freeze

    private

    def check_role(driver, role, text, checked: nil, disabled: nil)
      ensure_driver!(driver)
      state = State.new(driver.state_data)
      selector = Selector.new(state)

      filters = {}
      filters[:text] = text.to_s if text
      filters[:checked] = checked unless checked.nil?
      filters[:disabled] = disabled unless disabled.nil?
      elements = selector.get_by_role(role, **filters)

      action = "assert_#{role}"
      if elements.any?
        count = elements.size
        desc = text ? "#{role} #{text.inspect}" : role.to_s
        desc += " (checked)" if checked == true
        desc += " (unchecked)" if checked == false
        desc += " (disabled)" if disabled == true
        Result.new(step: action, passed: true, message: "Found #{count} #{desc} element(s)")
      else
        desc = text ? "#{role} with text #{text.inspect}" : role.to_s
        desc += " (checked)" if checked == true
        desc += " (disabled)" if disabled == true
        Result.new(step: action, passed: false, message: "No #{desc} found")
      end
    end

    def safe_output_path(value, ext)
      default = File.join("/tmp", "tui_td_#{Time.now.to_i}.#{ext}")
      resolved = File.expand_path(value.is_a?(String) ? value : default)

      unless ALLOWED_OUTPUT_DIRS.any? { |dir| resolved.start_with?(File.expand_path(dir)) }
        raise TUITD::Error, "Output path must be under one of: #{ALLOWED_OUTPUT_DIRS.join(", ")}"
      end

      resolved
    end

    def ensure_driver!(driver)
      raise Error, "No session. Add a 'start' step first." if driver.nil?
    end

    def coords(step)
      pos = step[:assert_fg] || step[:assert_bg] || step[:assert_style]
      row = pos.is_a?(Array) ? pos[0] : (pos[:row] || pos["row"] || 0)
      col = pos.is_a?(Array) ? pos[1] : (pos[:col] || pos["col"] || 0)
      [row, col]
    end

    def check_text(driver, value, action)
      ensure_driver!(driver)
      text = value.to_s

      if action == "assert_regex"
        begin
          pattern = Regexp.new(text)
        rescue RegexpError => e
          return Result.new(step: action, passed: false, message: "Invalid regex: #{e.message}")
        end
      else
        pattern = text
      end

      found = if action == "assert_not_text"
                state = State.new(driver.state_data)
                state.find_text(pattern).any?
              else
                begin
                  driver.wait_for(timeout: 2) { |s| s.find_text(pattern).any? }
                  true
                rescue TimeoutError
                  false
                end
              end

      case action
      when "assert_text"
        if found
          Result.new(step: action, passed: true, message: "Text found: #{value}")
        else
          Result.new(step: action, passed: false, message: "Text NOT found: #{value}")
        end
      when "assert_not_text"
        if found
          Result.new(step: action, passed: false, message: "Text found but should not be: #{value}")
        else
          Result.new(step: action, passed: true, message: "Text not found: #{value}")
        end
      when "assert_regex"
        if found
          Result.new(step: action, passed: true, message: "Regex matched: #{value}")
        else
          Result.new(step: action, passed: false, message: "Regex did not match: #{value}")
        end
      else
        Result.new(step: action, passed: false, message: "Unknown text check: #{action}")
      end
    end

    def check_color(driver, step, property)
      ensure_driver!(driver)
      row, col = coords(step)
      expected = step[:is] || step["is"]
      label = property == :fg ? "FG" : "BG"

      actual_val = nil
      found = begin
        driver.wait_for(timeout: 2) do |s|
          actual_val = property == :fg ? s.foreground_at(row, col) : s.background_at(row, col)
          actual_val == expected
        end
        true
      rescue TimeoutError
        # actual_val holds the last observed value
        false
      end

      actual_val ||= begin
        state = State.new(driver.state_data)
        property == :fg ? state.foreground_at(row, col) : state.background_at(row, col)
      end

      if found
        Result.new(step: step.keys.first.to_s, passed: true, message: "#{label} at [#{row},#{col}] is #{expected}")
      else
        Result.new(step: step.keys.first.to_s, passed: false,
                   message: "#{label} at [#{row},#{col}] is #{actual_val}, expected #{expected}",)
      end
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/BlockLength, Metrics/ClassLength
