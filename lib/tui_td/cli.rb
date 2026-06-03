# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/BlockLength

require "optparse"

module TUITD
  # Command-line interface for tui-td
  class CLI
    def self.run(argv = ARGV)
      new.run(argv)
    end

    def run(argv)
      global_opts = {}
      nil
      command_opts = {}

      OptionParser.new do |opts|
        opts.banner = "Usage: tui-td <command> [options]"
        opts.separator ""
        opts.separator "Commands:"
        opts.separator "  serve              Start MCP server (JSON-RPC over stdio)"
        opts.separator "  capture <command>  Run once, capture and display state"
        opts.separator "  drive <command>    Drive a TUI interactively"
        opts.separator "  run <command>      Run a TUI app and show live output"
        opts.separator "  test <file.json>   Run JSON test file"
        opts.separator "  help [topic]       Show this help, or help test / help rspec"
        opts.separator ""
        opts.separator "Examples:"
        opts.separator "  tui-td capture \"ls -la\""
        opts.separator "  tui-td --screenshot out.png capture \"htop\" --timeout 5"
        opts.separator "  tui-td --html out.html capture \"glow README.md\""
        opts.separator "  tui-td -C /my/project capture \"make test\""
        opts.separator "  tui-td drive \"vim file.txt\" --rows 24 --cols 80"
        opts.separator "  tui-td test examples/echo_test.json"
        opts.separator "  tui-td -vl test examples/vim_hello_world.json"
        opts.separator "  tui-td serve"
        opts.separator ""
        opts.separator "Interactive commands (drive mode):"
        opts.separator "  state              Show terminal state as pretty JSON"
        opts.separator "  raw                Show raw ANSI output"
        opts.separator "  elements           Show detected UI elements (buttons, dialogs, etc.)"
        opts.separator "  key <name>         Send keystroke (enter, tab, escape, up, down, left, right,"
        opts.separator "                     backspace, ctrl_c, ctrl_d)"
        opts.separator "  <text>             Send text to the TUI"
        opts.separator "  exitstatus         Show process exit status (nil if running)"
        opts.separator "  exit               Quit drive mode"
        opts.separator ""
        opts.separator "Global options:"

        opts.on("-r", "--rows N", Integer, "Terminal rows (default: 40)") do |r|
          global_opts[:rows] = r
        end
        opts.on("-c", "--cols N", Integer, "Terminal cols (default: 120)") do |c|
          global_opts[:cols] = c
        end
        opts.on("-t", "--timeout SECONDS", Integer, "Timeout in seconds (default: 30)") do |t|
          global_opts[:timeout] = t
        end
        opts.on("-C", "--chdir PATH", "Working directory for the command") do |d|
          global_opts[:chdir] = d
        end
        opts.on("--screenshot PATH", "Save screenshot (e.g., output.png)") do |p|
          global_opts[:screenshot] = p
        end
        opts.on("--html PATH", "Save HTML render (e.g., output.html)") do |p|
          global_opts[:html] = p
        end
        opts.on("--json", "Output state as compact JSON") do |_|
          global_opts[:format] = :json
        end
        opts.on("--pretty", "Output state as pretty JSON") do |_|
          global_opts[:format] = :pretty_json
        end
        opts.on("--text", "Output state as plain text table") do |_|
          global_opts[:format] = :text
        end
        opts.on("-v", "--verbose", "Show each test step as it runs") do |_|
          global_opts[:verbose] = true
        end
        opts.on("-l", "--live", "Show terminal state after each step (screen-refresh)") do |_|
          global_opts[:live] = true
        end
        opts.on("-s", "--step", "Pause after each test step for confirmation") do |_|
          global_opts[:step_mode] = true
        end
        opts.on("--version", "Show version") do
          puts "tui-td #{TUITD::VERSION}"
          exit 0
        end
        opts.on("-h", "--help", "Show help") do
          puts opts
          exit 0
        end
      end.permute!(argv)

      command = argv.shift
      command_opts[:args] = argv

      case command
      when "serve"
        cmd_serve(global_opts)
      when "run"
        cmd_run(command_opts, global_opts)
      when "drive"
        cmd_drive(command_opts, global_opts)
      when "capture"
        cmd_capture(command_opts, global_opts)
      when "test"
        cmd_test(command_opts, global_opts)
      when "help"
        topic = argv.shift
        case topic
        when "test"
          _help_test
        when "rspec"
          _help_rspec
        when nil
          _help_main
        else
          abort "Unknown help topic: #{topic.inspect}\nTry: tui-td help test, tui-td help rspec"
        end
      when nil
        _help_main
      else
        abort "Unknown command: #{command.inspect}\nUse tui-td --help for usage"
      end
    end

    private

    def cmd_serve(globals)
      server = MCP::Server.new(
        rows: globals[:rows] || 40,
        cols: globals[:cols] || 120,
        timeout: globals[:timeout] || 30,
      )
      server.start
    end

    def cmd_run(opts, globals)
      args = opts[:args]
      abort "Usage: tui-td run <command>" if args.empty?
      cmd = args.join(" ")

      driver = Driver.new(cmd, **globals.slice(:rows, :cols, :timeout, :chdir))
      puts "Starting: #{cmd}"
      puts "─" * (globals[:cols] || 80)
      driver.start

      driver.wait_for_stable

      if %i[json pretty_json].include?(globals[:format])
        puts driver.state_json(pretty: globals[:format] == :pretty_json)
      else
        _render_text(driver.state_data)
      end

      if globals[:screenshot]
        path = driver.screenshot(globals[:screenshot])
        puts "Screenshot saved: #{path}"
      end
      if globals[:html]
        path = HtmlRenderer.new(driver.state_data).render(globals[:html])
        puts "HTML saved: #{path}"
      end

      driver.close
    end

    def cmd_drive(opts, globals)
      args = opts[:args]
      abort "Usage: tui-td drive <command>" if args.empty?
      cmd = args.join(" ")

      driver = Driver.new(cmd, **globals.slice(:rows, :cols, :timeout, :chdir))
      puts "Starting interactive drive: #{cmd}"
      puts "Type commands to send. Exit with Ctrl+C."
      driver.start

      begin
        loop do
          driver.wait_for_stable
          print "> "
          input = $stdin.gets
          break unless input

          input = input.chomp
          break if input == "exit"

          if input == "state"
            puts driver.state_json(pretty: true)
          elsif input == "raw"
            puts driver.raw_output[0..2000]
          elsif input == "exitstatus"
            status = driver.exitstatus
            puts status ? "Exit status: #{status}" : "Process still running"
          elsif input == "elements"
            state = State.new(driver.state_data)
            selector = Selector.new(state)
            puts "Buttons:    #{selector.buttons.map { |e| "#{e.text}@[#{e.row},#{e.col}]" }.join(", ")}"
            puts "Checkboxes: #{selector.checkboxes.map { |e| "#{e.text} (#{e.checked ? "✓" : "☐"})" }.join(", ")}"
            puts "Dialogs:    #{selector.dialogs.map { |e| "\"#{e.text}\" #{e.width}x#{e.height}" }.join(", ")}"
            puts "Statusbars: #{selector.statusbars.map(&:text).join(", ")}"
            puts "Progress:   #{selector.progress_bars.map(&:text).join(", ")}"
          elsif input.start_with?("key ")
            driver.send_keys(input.split(" ", 2).last.to_sym)
          else
            driver.send("#{input}\n")
          end
        end
      rescue Interrupt
        puts "\nDone."
      ensure
        driver.close
      end
    end

    def cmd_capture(opts, globals)
      args = opts[:args]
      abort "Usage: tui-td capture <command>" if args.empty?
      cmd = args.join(" ")

      driver = Driver.new(cmd, **globals.slice(:rows, :cols, :timeout, :chdir))
      begin
        driver.start
      rescue TimeoutError
        # Interactive TUI that never stabilizes (e.g., glow without -p).
        # Proceed with whatever was rendered before the timeout.
        driver.refresh
      end
      begin
        driver.wait_for_stable
      rescue TimeoutError
        # Ignored — already have rendered state from start
      end

      case globals[:format]
      when :json
        puts driver.state_json(pretty: false)
      when :pretty_json
        puts driver.state_json(pretty: true)
      else
        _render_text(driver.state_data)
      end

      if globals[:screenshot]
        path = driver.screenshot(globals[:screenshot])
        puts "Screenshot saved: #{path}"
      end
      if globals[:html]
        path = HtmlRenderer.new(driver.state_data).render(globals[:html])
        puts "HTML saved: #{path}"
      end

      driver.close
    end

    def cmd_test(opts, globals)
      args = opts[:args]
      abort "Usage: tui-td test <file.json>" if args.empty?

      path = args.first
      abort "File not found: #{path}" unless File.exist?(path)

      verbose = globals[:verbose]
      live = globals[:live]
      step_mode = globals[:step_mode]

      on_step = if verbose || live || step_mode
                  lambda do |info|
                    info[:driver].wait_for_stable(stable_ms: 200) if live && info[:driver]
                    if verbose
                      status = info[:result].passed ? "PASS" : "FAIL"
                      puts "[#{info[:index] + 1}/#{info[:total]}] #{info[:action]}: #{info[:result].message}"
                      puts "      → #{status}"
                    end
                    if live && info[:driver]
                      print "\e[2J\e[H" # clear screen, home cursor
                      _render_text(info[:driver].state_data)
                    end
                    if step_mode
                      print "\n[Enter=weiter, q=abbruch] "
                      input = $stdin.gets
                      exit 1 if input&.chomp == "q"
                    end
                  end
                end

      require "json"
      plan = JSON.parse(File.read(path), symbolize_names: true)
      runner = TestRunner.new(plan, on_step: on_step)
      result = runner.run

      puts
      puts "Test: #{result[:name]}"
      puts "Status: #{result[:passed] ? "PASSED" : "FAILED"}"
      puts "-" * 40

      result[:results].each do |r|
        status = r[:passed] ? "PASS" : "FAIL"
        puts "  [#{status}] #{r[:step]}: #{r[:message]}"
      end

      exit 1 unless result[:passed]
    end

    def _render_text(state)
      rows = state.dig(:size, :rows) || 40
      cols = state.dig(:size, :cols) || 120
      grid = state[:rows] || []
      cursor = state[:cursor] || {}

      puts "Terminal: #{cols}x#{rows}  Cursor: [#{cursor[:row]}, #{cursor[:col]}]"
      puts "─" * [cols, 80].min

      grid.each_with_index do |row, _ri|
        line = row.map { |cell| cell[:char] }.join
        puts line.empty? ? "~" : line
      end
    end

    def _help_main
      puts(OptionParser.new { |o| o.banner = "Usage: tui-td <command> [options]" })
      puts
      puts "For more: tui-td help test   (JSON test step types)"
      puts "          tui-td help rspec  (RSpec matchers)"
      exit 0
    end

    def _help_test
      puts <<~HELP
        JSON Test Format
        ================

        Run from CLI:

          tui-td test examples/echo_test.json
          tui-td -v test examples/echo_test.json   (verbose: show each step)
          tui-td -vl test examples/echo_test.json  (verbose + live terminal view)
          tui-td -vs test examples/echo_test.json  (verbose + pause after each step)
          tui-td -vls test examples/vim_hello_world.json  (all three: watch vim edit live)

        Or from Ruby code:

          require "tui_td/test_runner"
          runner = TUITD::TestRunner.new(name: "my test", steps: [...])
          result = runner.run  # => { passed: true, results: [...] }

        A test is a Hash or JSON string: {"name": "...", "steps": [...]}

        Top-level keys: name, steps, rows (default 40), cols (default 120),
                        timeout (default 30), chdir, before_all, after_all

        before_all / after_all are arrays of steps that run before and
        after the main steps list. Useful for setup/teardown:

          "before_all": [{"start": "my_tui"}, {"wait_for_text": "> "}],
          "steps": [{"send": "hello\\n"}],
          "after_all": [{"close": true}]

        Each step can also set a per-step "timeout" (in seconds):

          {"wait_for_text": "Slow", "timeout": 60}

        Each step is an object with a single action key:

          {"start": "<command>"}
              Start a TUI process in a PTY. Environment variables can be
              passed via "env": {"FOO": "bar", "BAZ": "qux"}.

          {"send": "<text>"}
              Send text to the TUI. Use "\\n" for Enter.

          {"send_key": "<name>"}
              Send a keystroke. Names: enter, tab, escape, up, down,
              left, right, backspace, ctrl_c, ctrl_d.

          {"wait_for_text": "<substring>"}
              Wait until the given text appears in the output.

          {"wait_for_stable": true}
              Wait until the output stops changing (default 300ms quiet).

          {"assert_text": "<substring>"}
              Fail if the text is not found in the current state.

          {"assert_not_text": "<substring>"}
              Fail if the text IS found in the current state.

          {"assert_regex": "<pattern>"}
              Fail if the regex pattern does not match anywhere.
              Pattern syntax is Ruby regex (e.g. "error|fail|warn").

          {"assert_fg": [row, col], "is": "<color>"}
              Assert foreground color at cell. Colors: "default",
              named ANSI (red, green, blue, cyan, ...), "bright_*",
              "color<N>" (256-color), "#rrggbb" (TrueColor).

          {"assert_bg": [row, col], "is": "<color>"}
              Assert background color at cell. Same color format.

          {"assert_style": [row, col], "bold": true, "italic": false, ...}
              Assert style attributes at cell. Checks only the keys provided.

          {"screenshot": "<path>"}
              Save a PNG screenshot. Path defaults to /tmp/tui_td_<ts>.png.

          {"html": "<path>"}
              Save an HTML render. Path defaults to /tmp/tui_td_<ts>.html.

          {"wait_for_exit": true}
              Wait until the process exits naturally.

          {"assert_exit": <N>}
              Assert the process exit status equals N.

          {"close": true}
              Close the driver session (force-kill if needed).

          {"assert_button": "<text>"}
              Find a button with the given text. Buttons are detected
              by patterns like [ OK ], (Cancel), <Submit>.

          {"assert_dialog": true}
              Assert that at least one dialog (box-drawing region) is visible.

          {"assert_checkbox": "<text>", "checked": true}
              Find a checkbox with the given label text. Optional "checked"
              (true/false) to match checked state. Detects [x], [*], [ ] at
              line starts.

          {"assert_role": ":button", "text": "OK"}
              Generic role assertion. Accepts :button, :checkbox, :dialog,
              :statusbar, :progress. Optional "text" filter.

        Example test file: examples/echo_test.json
      HELP
      exit 0
    end

    def _help_rspec
      puts <<~HELP
        RSpec Matchers
        ==============

        Matchers work on TUITD::State objects, not raw output.
        Get a State from the Driver:

          require "tui_td"
          require "tui_td/matchers"

          driver = TUITD::Driver.new("my_tui", rows: 24, cols: 80)
          driver.start
          state = TUITD::State.new(driver.state_data)

          expect(state).to have_text("Hello")
          expect(state).to have_fg("red").at(0, 5)

          driver.close

        Or build a State manually for unit tests:

          state = TUITD::State.new(
            size: { rows: 5, cols: 20 },
            cursor: { row: 0, col: 0 },
            rows: [[{ char: "H", fg: "default", bg: "default",
                      bold: false, italic: false, underline: false }]]
          )

        Matchers
        --------

        have_text(expected)
            Passes if expected text appears anywhere in the terminal state.
            Usage: expect(state).to have_text("Hello")
            Negate: expect(state).not_to have_text("Error")

        have_regex(pattern)
            Passes if the regex pattern matches anywhere. Accepts a Regexp
            or a string (parsed as Ruby regex).
            Usage: expect(state).to have_regex(/error|fail/)
            Usage: expect(state).to have_regex("\\d{3}")

        have_fg(expected).at(row, col)
            Assert foreground color at [row, col] matches expected.
            Usage: expect(state).to have_fg("red").at(0, 5)

        have_bg(expected).at(row, col)
            Assert background color at [row, col] matches expected.
            Usage: expect(state).to have_bg("default").at(0, 0)

        have_style.at(row, col).with(bold: true, italic: false, ...)
            Assert style attributes at [row, col] match the given hash.
            Usage: expect(state).to have_style.at(0, 0).with(bold: true)

        Selector matchers (semantic UI element detection)
        -------------------------------------------------

        These matchers detect UI elements by their visual appearance:

        have_button("OK")
            Passes if a button with the given text is visible.
            Detects [ OK ], (Cancel), <Submit> patterns.
            Usage: expect(state).to have_button("OK")

        have_dialog
            Passes if a dialog (box-drawing character region) is visible.
            Usage: expect(state).to have_dialog

        have_checkbox("Enable").checked
            Passes if a checkbox with the given label is visible.
            Chain .checked to require the box to be checked.
            Detects [x], [*], [ ] at line starts.
            Usage: expect(state).to have_checkbox("Enable logging")
            Usage: expect(state).to have_checkbox("Auto-save").checked

        have_role(:button, text: "OK")
            Generic role matcher. Accepts :button, :checkbox, :dialog,
            :statusbar, :progress. Optional text: filter.
            Usage: expect(state).to have_role(:statusbar)

        Driver matchers (work on TUITD::Driver, not State)
        --------------------------------------------------

        have_exit_status(expected)
            Assert the process exit status matches expected.
            Usage: expect(driver).to have_exit_status(0)
      HELP
      exit 0
    end
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/BlockLength
