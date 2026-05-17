# frozen_string_literal: true

require "optparse"

module TUITD
  # Command-line interface for tui-td
  class CLI
    def self.run(argv = ARGV)
      new.run(argv)
    end

    def run(argv)
      global_opts = {}
      command = nil
      command_opts = {}

      OptionParser.new do |opts|
        opts.banner = "Usage: tui-td <command> [options]"
        opts.separator ""
        opts.separator "Commands:"
        opts.separator "  serve              Start MCP server (JSON-RPC over stdio)"
        opts.separator "  capture <command>  Run once, capture and display state"
        opts.separator "  drive <cmd>        Drive a TUI interactively"
        opts.separator "  run <command>      Run a TUI app and show live output"
        opts.separator "  test <file.json>   Run JSON test file"
        opts.separator "  help               Show this help"
        opts.separator ""
        opts.separator "Examples:"
        opts.separator "  tui-td capture \"ls -la\""
        opts.separator "  tui-td --screenshot out.png capture \"htop\" --timeout 5"
        opts.separator "  tui-td --html out.html capture \"glow README.md\""
        opts.separator "  tui-td -C /my/project capture \"make test\""
        opts.separator "  tui-td drive \"vim file.txt\" --rows 24 --cols 80"
        opts.separator "  tui-td test examples/echo_test.json"
        opts.separator "  tui-td serve"
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
      when nil, "help"
        puts OptionParser.new { |o| o.banner = "Usage: tui-td <command> [options]" }
        exit 0
      else
        abort "Unknown command: #{command.inspect}\nUse tui-td --help for usage"
      end
    end

    private

    def cmd_serve(globals)
      server = MCP::Server.new(
        rows: globals[:rows] || 40,
        cols: globals[:cols] || 120,
        timeout: globals[:timeout] || 30
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

      if globals[:format] == :json || globals[:format] == :pretty_json
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
          elsif input.start_with?("key ")
            driver.send_keys(input.split(" ", 2).last.to_sym)
          else
            driver.send(input + "\n")
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
      driver.start
      driver.wait_for_stable

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

      require "json"
      plan = JSON.parse(File.read(path), symbolize_names: true)
      runner = TestRunner.new(plan)
      result = runner.run

      puts
      puts "Test: #{result[:name]}"
      puts "Status: #{result[:passed] ? 'PASSED' : 'FAILED'}"
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
  end
end
