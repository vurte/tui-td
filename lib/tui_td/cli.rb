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
        opts.separator "  snapshot <name>    Save current state as named snapshot to disk"
        opts.separator "  snapshot           Save current state in-memory (legacy)"
        opts.separator "  diff <name>        Compare current state against named snapshot on disk"
        opts.separator "  diff               Compare against in-memory snapshot (legacy)"
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
        opts.on("--record PATH", "Record session as video (MP4/WebM, requires ffmpeg)") do |p|
          global_opts[:record] = p
        end
        opts.on("--framerate N", Integer, "Recording framerate (default: 30)") do |f|
          global_opts[:record_framerate] = f
        end
        opts.on("--codec NAME", "Video codec: libx264, libx265, libvpx-vp9 (default: libx264)") do |c|
          global_opts[:record_codec] = c
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
        when "minitest"
          _help_minitest
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

    def _start_recording_if(driver, globals)
      return unless globals[:record]

      framerate = globals[:record_framerate] || 30
      codec = globals[:record_codec] || "libx264"
      path = driver.start_recording(globals[:record], framerate: framerate, codec: codec)
      puts "Recording to: #{path}"
      path
    end

    def _stop_recording(driver)
      return unless driver.recording?

      path = driver.stop_recording
      puts "Recording saved: #{path}" if path
    end

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

      _start_recording_if(driver, globals)

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

      _stop_recording(driver)
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

      _start_recording_if(driver, globals)

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
            puts "Inputs:     #{selector.inputs.map { |e| "[__]@[#{e.row},#{e.col}]" }.join(", ")}"
            puts "Labels:     #{selector.labels.map(&:text).join(", ")}"
            puts "Menus:      #{selector.menus.map(&:text).join(", ")}"
            puts "Tabs:       #{selector.tabs.map { |e| "#{e.text}#{" (focused)" if e.focused}" }.join(", ")}"
            puts "Statusbars: #{selector.statusbars.map(&:text).join(", ")}"
            puts "Progress:   #{selector.progress_bars.map(&:text).join(", ")}"
          elsif input.start_with?("snapshot ")
            name = input.split(" ", 2).last.strip
            unless name.empty?
              snap = Snapshot.new(name)
              snap.save(driver.state_data)
              puts "Snapshot '#{name}' saved to #{snap.path}."
            end
          elsif input == "snapshot"
            @last_snapshot = State.new(driver.state_data)
            puts "In-memory snapshot saved."
          elsif input.start_with?("diff ")
            name = input.split(" ", 2).last.strip
            unless name.empty?
              snap = Snapshot.new(name)
              unless snap.exists?
                puts "No snapshot '#{name}' found at #{snap.path}."
                next
              end
              result = snap.compare(driver.state_data)
              if result.passed?
                puts "No differences. Snapshot '#{name}' matches."
              else
                puts result.message
              end
            end
          elsif input == "diff"
            if @last_snapshot
              current = State.new(driver.state_data)
              diffs = current.diff(@last_snapshot)
              if diffs.empty?
                puts "No differences."
              else
                puts "#{diffs.size} difference(s):"
                diffs.first(10).each do |d|
                  puts "  [#{d[:row]},#{d[:col]}] #{d[:before][:char].inspect} -> #{d[:after][:char].inspect}"
                end
                puts "  ..." if diffs.size > 10
              end
            else
              puts "No snapshot saved. Use 'snapshot <name>' or 'snapshot' first."
            end
          elsif input.start_with?("key ")
            driver.send_keys(input.split(" ", 2).last.to_sym)
          else
            driver.send("#{input}\n")
          end
        end
      rescue Interrupt
        puts "\nDone."
      ensure
        _stop_recording(driver)
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

      _start_recording_if(driver, globals)

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

      _stop_recording(driver)
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
      puts "For more: tui-td help test     (JSON test step types)"
      puts "          tui-td help rspec    (RSpec matchers)"
      puts "          tui-td help minitest (Minitest assertions)"
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

          {"start_recording": "<path>", "framerate": 30, "codec": "libx264"}
              Start recording the TUI session as a video (requires ffmpeg).
              framerate defaults to 30, codec defaults to libx264.

          {"stop_recording": true}
              Stop video recording and finalize the video file.

          {"assert_recording": true}
              Assert that recording is active. Use false to assert NOT recording.

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
              :statusbar, :progress, :input, :label, :menu, :tab.
              Optional "text", "checked", and "disabled" filters.

          {"assert_input": true} or {"assert_input": "text"}
              Assert that an input field ([____]) is visible. Optional text
              filter to match adjacent label.

          {"assert_label": "Name"}
              Assert that a label (text ending with colon) is visible.

          {"assert_menu": true} or {"assert_menu": "File | Edit"}
              Assert that a menu bar or dropdown item is visible.

          {"assert_tab": "File"}
              Assert that a tab ([Tab1]) is visible.

          {"assert_statusbar": true}
              Assert that a status bar (bottom row with background) is visible.

          {"assert_progress_bar": true} or {"assert_progress_bar": "50%"}
              Assert that a progress bar ([####   ]) is visible.

          {"snapshot": "login_screen", "type": "text", "wait": true}
              Save current terminal state as a named snapshot to disk.
              type: "text" (default), "full", "png", "html", "all".

          {"assert_snapshot": "login_screen", "type": "text", "wait": true}
              Assert current state matches a saved named snapshot.
              First run creates the golden master (passes automatically).
              UPDATE_SNAPSHOTS=1 to force update all snapshots.

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
            :statusbar, :progress, :input, :label, :menu, :tab.
            Optional text:, checked:, disabled: filters.
            Usage: expect(state).to have_role(:statusbar)

        have_input
            Passes if an input field ([____]) is visible.
            Usage: expect(state).to have_input
            Usage: expect(state).to have_input("Name")

        have_label("Name")
            Passes if a label (text ending with colon) is visible.
            Usage: expect(state).to have_label("Name")

        have_menu
            Passes if a menu bar or dropdown item is visible.
            Usage: expect(state).to have_menu

        have_tab("File")
            Passes if a tab is visible.
            Usage: expect(state).to have_tab("File")

        have_statusbar
            Passes if a status bar (bottom row with background) is visible.
            Usage: expect(state).to have_statusbar

        have_progress_bar
            Passes if a progress bar ([####   ]) is visible.
            Usage: expect(state).to have_progress_bar

        match_snapshot("<name>", type: :text, wait: false, region: 0..6, ignore_rows: [2])
            Named, persisted snapshot testing. First run creates the snapshot
            (passes automatically), subsequent runs compare.
            Types: :text (chars_only, default), :full (chars+colors), :png, :html, :all.
            region: restricts comparison to a row range (e.g., 0..6).
            ignore_rows: skips specific rows during comparison.
            UPDATE_SNAPSHOTS=1 to auto-update all snapshots.
            Usage: expect(driver).to match_snapshot("login_screen")
            Usage: expect(driver).to match_snapshot("banner", region: 0..6, chars_only: true)
            Usage: expect(driver).to match_snapshot("main", ignore_rows: [5], wait: true)

        match_snapshot(State, chars_only: false)  (legacy in-memory)
            Passes if the current state matches a previously saved snapshot object.
            Usage: pre = driver.snapshot; ... ; expect(driver).to match_snapshot(pre)
            Usage: expect(state).to match_snapshot(snap, chars_only: true)

        Driver matchers (work on TUITD::Driver, not State)
        --------------------------------------------------

        have_exit_status(expected)
            Assert the process exit status matches expected.
            Usage: expect(driver).to have_exit_status(0)

        Video Recording
        ---------------

        Start/stop recording via Driver methods, then verify with matchers:

          driver.start_recording("test.mp4", framerate: 30, codec: "libx264")
          expect(driver).to be_recording
          # ... interact with TUI ...
          driver.stop_recording
          expect(driver).not_to be_recording
          expect(driver).to have_recorded_video("test.mp4")

        Options for start_recording: framerate (default 30),
        codec (libx264, libx265, libvpx-vp9), quality (high/medium/low).
        Recording stops automatically when the driver is closed.
      HELP
      exit 0
    end

    def _help_minitest
      puts <<~HELP
        Minitest Assertions
        ===================

        Include the assertions module in your Minitest test class:

          require "tui_td/minitest/assertions"

          class MyTUITest < Minitest::Test
            include TUITD::Minitest::Assertions

            def setup
              @driver = TUITD::Driver.new("my_tui", rows: 24, cols: 80)
              @driver.start
            end

            def teardown
              @driver&.close
            end
          end

        Auto-wait: When given a Driver, assertions wait up to 3 seconds.
        When given a State, assertions check immediately.

        Assertions
        ----------

        Text / Regex / Color / Style:

        assert_text(driver, "Welcome")
            Passes if text appears anywhere in the terminal.
            Negate: refute_text(driver, "Error")

        assert_regex(driver, /error|fail/)
            Passes if regex pattern matches anywhere.
            Negate: refute_regex(driver, /pattern/)

        assert_fg(driver, "cyan", row: 0, col: 5)
            Assert foreground color at position.

        assert_bg(driver, "blue", row: 0, col: 0)
            Assert background color at position.

        assert_style(driver, row: 0, col: 0, bold: true, italic: false)
            Assert style attributes at position.

        assert_exit_status(driver, 0)
            Assert the process exit status matches expected.

        Selector assertions:

        assert_button(driver, "OK")
            Passes if a button with given text is visible.
            Negate: refute_button(driver, "Cancel")

        assert_dialog(driver)
            Passes if a dialog (box-drawing region) is visible.
            Negate: refute_dialog(driver)

        assert_checkbox(driver, "Label", checked: true)
            Passes if checkbox with given label (and optionally state) is visible.
            Use checked: true, checked: false, or unchecked: true.

        assert_role(driver, :button, text: "OK", checked: nil, disabled: nil)
            Generic role assertion. Accepts :button, :checkbox, :dialog,
            :statusbar, :progress, :input, :label, :menu, :tab.

        assert_input(driver)
        assert_input(driver, "Name")
            Passes if an input field ([____]) is visible.

        assert_label(driver, "Username")
            Passes if a label (text ending with colon) is visible.

        assert_menu(driver)
            Passes if a menu bar or dropdown item is visible.

        assert_tab(driver, "File")
            Passes if a tab is visible.

        assert_statusbar(driver)
            Passes if a status bar (bottom row with background) is visible.

        assert_progress_bar(driver, "50%")
            Passes if a progress bar ([####   ]) is visible.

        Snapshot:

        assert_snapshot(driver, "login_screen", type: :text, wait: true)
            Named snapshot testing. First run creates golden master,
            subsequent runs compare.

        assert_snapshot(driver, "banner", region: 0..6, chars_only: true)
            Partial screen comparison with region:.

        assert_snapshot(driver, "main", ignore_rows: [5])
            Skip volatile rows with ignore_rows:.

        Video Recording
        ---------------

        assert_record_start(driver, "test.mp4", framerate: 30, codec: "libx264")
            Start recording the TUI session as a video (requires ffmpeg).

        assert_record_stop(driver)
            Stop recording and finalize the video file.

        assert_recording(driver)
            Verify that recording is currently active.

        refute_recording(driver)
            Verify that recording is NOT active.
      HELP
      exit 0
    end
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/BlockLength
