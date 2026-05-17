# frozen_string_literal: true

require "json"

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
  #     "steps": [
  #       {"start": "my_tui"},
  #       {"wait_for_text": "> "},
  #       {"send": "hello\n"},
  #       {"assert_text": "hello"},
  #       {"assert_fg": [0, 0], "is": "cyan"},
  #       {"close": true}
  #     ]
  #   }
  #
  class TestRunner
    Result = Struct.new(:step, :passed, :message, keyword_init: true)

    def initialize(source, on_step: nil)
      raw = source.is_a?(String) ? JSON.parse(source) : source
      @plan = raw.transform_keys(&:to_sym)
      @plan[:steps] = @plan[:steps].map { |s| s.transform_keys(&:to_sym) }
      @on_step = on_step
    end

    def run
      results = []
      all_passed = true
      driver = nil
      rows = @plan[:rows] || 40
      cols = @plan[:cols] || 120
      timeout = @plan[:timeout] || 30
      chdir = @plan[:chdir]

      @plan[:steps].each do |step|
        action = step.keys.first.to_s
        value = step.values.first
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          r = case action
              when "start"
                driver&.close
                driver = Driver.new(value.to_s, rows: rows, cols: cols, timeout: timeout, chdir: chdir)
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

              when "assert_text"
                ensure_driver!(driver)
                state = State.new(driver.state_data)
                if state.find_text(value.to_s).any?
                  Result.new(step: action, passed: true, message: "Text found: #{value}")
                else
                  Result.new(step: action, passed: false, message: "Text NOT found: #{value}")
                end

              when "assert_fg"
                ensure_driver!(driver)
                row, col = coords(step)
                expected = step[:is] || step["is"]
                state = State.new(driver.state_data)
                actual = state.foreground_at(row, col)
                if actual == expected
                  Result.new(step: action, passed: true, message: "FG at [#{row},#{col}] is #{expected}")
                else
                  Result.new(step: action, passed: false, message: "FG at [#{row},#{col}] is #{actual}, expected #{expected}")
                end

              when "assert_bg"
                ensure_driver!(driver)
                row, col = coords(step)
                expected = step[:is] || step["is"]
                state = State.new(driver.state_data)
                actual = state.background_at(row, col)
                if actual == expected
                  Result.new(step: action, passed: true, message: "BG at [#{row},#{col}] is #{expected}")
                else
                  Result.new(step: action, passed: false, message: "BG at [#{row},#{col}] is #{actual}, expected #{expected}")
                end

              when "assert_style"
                ensure_driver!(driver)
                row, col = coords(step)
                state = State.new(driver.state_data)
                actual = state.style_at(row, col)
                expected = {}
                expected[:bold] = step[:bold] unless step[:bold].nil?
                expected[:italic] = step[:italic] unless step[:italic].nil?
                expected[:underline] = step[:underline] unless step[:underline].nil?
                match = expected.all? { |k, v| actual[k] == v }
                if match
                  Result.new(step: action, passed: true, message: "Style at [#{row},#{col}] matches #{expected}")
                else
                  Result.new(step: action, passed: false, message: "Style at [#{row},#{col}] is #{actual}, expected #{expected}")
                end

              when "screenshot"
                ensure_driver!(driver)
                path = value.is_a?(String) ? value : "/tmp/tui_td_#{Time.now.to_i}.png"
                driver.screenshot(path)
                Result.new(step: action, passed: true, message: "Saved: #{path}")

              when "html"
                ensure_driver!(driver)
                path = value.is_a?(String) ? value : "/tmp/tui_td_#{Time.now.to_i}.html"
                HtmlRenderer.new(driver.state_data).render(path)
                Result.new(step: action, passed: true, message: "Saved: #{path}")

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

        results << r
        all_passed &&= r.passed

        if @on_step
          state_data = nil
          begin
            state_data = driver.state_data if driver
          rescue StandardError
            # ignore — state retrieval is best-effort
          end
          @on_step.call(
            index: results.size - 1,
            total: @plan[:steps].size,
            action: action,
            value: value,
            result: r,
            state_data: state_data
          )
        end
      end

      driver&.close

      {
        name: @plan[:name] || "(unnamed)",
        passed: all_passed,
        results: results.map(&:to_h)
      }
    end

    private

    def ensure_driver!(driver)
      raise Error, "No session. Add a 'start' step first." if driver.nil?
    end

    def coords(step)
      pos = step[:assert_fg] || step[:assert_bg] || step[:assert_style]
      pos = value if pos.nil? && (value = step.values.first).is_a?(Array)
      row = pos.is_a?(Array) ? pos[0] : (pos[:row] || pos["row"] || 0)
      col = pos.is_a?(Array) ? pos[1] : (pos[:col] || pos["col"] || 0)
      [row, col]
    end
  end
end
