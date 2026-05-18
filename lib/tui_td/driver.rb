# frozen_string_literal: true

require "pty"
require "io/console"
require "json"

module TUITD
  # Drives a TUI application in a pseudo-terminal (PTY).
  #
  # Usage:
  #   driver = Driver.new("my_tui_app")
  #   driver.start
  #   driver.wait_for_text("> ")
  #   driver.send("Write hello\n")
  #   state = driver.state_json  # => structured JSON for AI
  #   driver.screenshot("out.png")
  #   driver.close
  #
  class Driver
    attr_reader :command, :state

    def initialize(command, rows: 40, cols: 120, timeout: 30, chdir: nil)
      @command = command
      @rows = rows
      @cols = cols
      @timeout = timeout
      @chdir = chdir
      @state = nil
      @stdin = nil
      @stdout = nil
      @wait_thr = nil
      @output_buffer = +""
      @output_mutex = Mutex.new
      @reader_thread = nil
      @reader_running = false
    end

    # Start the TUI application in a PTY
    def start
      env = { "TERM" => "xterm-256color", "COLUMNS" => @cols.to_s, "LINES" => @rows.to_s }
      spawn_opts = {}
      spawn_opts[:chdir] = @chdir if @chdir

      @stdout, @stdin, @pid = PTY.spawn(env, @command, spawn_opts)
      @stdout.winsize = [@rows, @cols]  # Set PTY window size for TUIs that check winsize
      @wait_thr = Process.detach(@pid)

      # Read until initial output stabilizes
      wait_for_stable
      refresh_state!

      _start_reader_thread

      true
    end

    # Send text to the TUI
    def send(text)
      ensure_running!
      @stdin&.print(text)
      @stdin&.flush
      true
    end

    # Send keys (escape sequences, control characters)
    def send_keys(keys)
      ensure_running!
      case keys
      when :enter then send("\r")
      when :tab   then send("\t")
      when :escape then send("\e")
      when :up    then send("\e[A")
      when :down  then send("\e[B")
      when :left  then send("\e[D")
      when :right then send("\e[C")
      when :backspace then send("\u007f")
      when :ctrl_c then send("\u0003")
      when :ctrl_d then send("\u0004")
      else send(keys.to_s)
      end
    end

    # Wait until output contains the given text
    def wait_for_text(text)
      deadline = monotonic + @timeout
      loop do
        raise TimeoutError, "Timeout waiting for: #{text.inspect}" if monotonic > deadline
        read_available!
        found = @output_mutex.synchronize { @output_buffer.include?(text) }
        break if found
        sleep 0.05
      end
      refresh_state!
    end

    # Wait for output to stabilize (no new data for N milliseconds)
    def wait_for_stable(stable_ms: 300)
      deadline = monotonic + @timeout
      last_change = monotonic

      loop do
        raise TimeoutError, "Timeout waiting for stable output" if monotonic > deadline

        if read_available!
          last_change = monotonic
        elsif (monotonic - last_change) * 1000 >= stable_ms
          break
        end

        sleep 0.05
      end
      refresh_state!
    end

    # Wait until the process finishes
    def wait_for_exit
      @wait_thr&.value
    end

    # Get the terminal output (raw ANSI + text)
    def raw_output
      read_available!
      @output_mutex.synchronize { @output_buffer.dup }
    end

    # Refresh the terminal state by re-parsing the output buffer.
    # Call this if the terminal content has changed and you need an up-to-date state.
    def refresh
      refresh_state!
      @state
    end

    # Get structured terminal state as a Hash
    def state_data
      refresh_state! if @state.nil?
      @state
    end

    # Get structured terminal state as JSON string
    def state_json(pretty: false)
      state_data
      pretty ? JSON.pretty_generate(@state) : JSON.generate(@state)
    end

    # Capture a PNG screenshot of the current terminal state
    def screenshot(output_path)
      state_data
      Screenshot.new(@state).render(output_path)
    end

    # Close the driver and clean up
    def close
      _stop_reader_thread

      # Kill the process if still running
      if @pid
        begin
          if Process.waitpid(@pid, Process::WNOHANG).nil?
            Process.kill("TERM", @pid) rescue nil
            sleep 0.05
            Process.kill("KILL", @pid) rescue nil
          end
        rescue Errno::ECHILD
          # Already reaped by Process.detach
        end
      end
      @stdin&.close rescue nil
      @stdout&.close rescue nil
      @stdin = @stdout = @pid = nil
    end

    private

    def _start_reader_thread
      @reader_running = true
      @reader_thread = Thread.new do
        loop do
          break unless @reader_running
          begin
            read_available!
          rescue IOError, Errno::EIO
            break
          end
          sleep 0.05
        end
      end
    end

    def _stop_reader_thread
      @reader_running = false
      if @reader_thread
        @reader_thread.join(1)
        @reader_thread.kill rescue nil
        @reader_thread = nil
      end
    end

    def ensure_running!
      raise Error, "Driver not started. Call #start first." if @stdin.nil?
      raise Error, "Process exited (status: #{@wait_thr&.value&.exitstatus})" unless @wait_thr&.alive?
    end

    def read_available!
      return false unless @stdout

      data = @stdout.read_nonblock(4096)

      @output_mutex.synchronize { @output_buffer << data }

      respond_to_dsr if data.include?("\e[6n")

      true
    rescue IO::WaitReadable, EOFError
      false
    end

    def respond_to_dsr
      @output_mutex.synchronize do
        @state = ANSIParser.parse(@output_buffer, @rows, @cols)
        @state[:raw] = @output_buffer.dup
        @output_buffer.gsub!("\e[6n", "")

        cursor = @state[:cursor]
        response = "\e[#{cursor[:row] + 1};#{cursor[:col] + 1}R"
        @stdin&.print(response)
        @stdin&.flush
      end
    end

    def refresh_state!
      @output_mutex.synchronize do
        @state = ANSIParser.parse(@output_buffer, @rows, @cols)
        @state[:raw] = @output_buffer.dup
      end
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
    end

  class TimeoutError < Error; end
end
