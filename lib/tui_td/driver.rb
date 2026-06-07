# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists
# rubocop:disable Naming/PredicateMethod

require "pty"
require "io/console"
require "json"
require "shellwords"

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
    FORBIDDEN_ENV = %w[PATH LD_PRELOAD LD_LIBRARY_PATH DYLD_INSERT_LIBRARIES
                       DYLD_FRAMEWORK_PATH RUBYOPT HOME RUBYLIB GEM_HOME GEM_PATH].freeze

    attr_reader :command, :state

    MAX_BUFFER_SIZE = 10 * 1024 * 1024 # 10 MB ring buffer

    def initialize(command, rows: 40, cols: 120, timeout: 30, chdir: nil, env: {}, poll_interval: nil)
      @command = command
      @rows = rows
      @cols = cols
      @timeout = timeout
      @chdir = chdir
      @env = sanitize_env(env)
      @state = nil
      @stdin = nil
      @stdout = nil
      @wait_thr = nil
      @output_buffer = +""
      @output_mutex = Mutex.new
      @reader_thread = nil
      @reader_running = false
      @poll_interval = poll_interval
    end

    # Start the TUI application in a PTY
    def start
      env = { "TERM" => "xterm-256color", "COLUMNS" => @cols.to_s,
              "LINES" => @rows.to_s, }.merge(@env.transform_keys(&:to_s))
      spawn_opts = {}
      spawn_opts[:chdir] = @chdir if @chdir

      cmd_args = Shellwords.shellsplit(@command)
      @stdout, @stdin, @pid = PTY.spawn(env, *cmd_args, spawn_opts)
      @stdout.winsize = [@rows, @cols] # Set PTY window size for TUIs that check winsize
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
      when :page_up   then send("\e[5~")
      when :page_down then send("\e[6~")
      else send(keys.to_s)
      end
    end

    # Wait until the predicate returns true for the current terminal state.
    # Polls with adaptive intervals: 10ms → 25ms → 50ms → 100ms.
    # Use a custom poll_interval to bypass adaptive behavior.
    #
    #   driver.wait_for { |state| state.find_text("Ready").any? }
    #   driver.wait_for(timeout: 5) { |state| state.foreground_at(0, 0) == "green" }
    #
    def wait_for(timeout: nil, &predicate)
      deadline = monotonic + (timeout || @timeout)
      loop_count = 0
      loop do
        raise TimeoutError, "Timeout waiting for predicate" if monotonic > deadline

        read_available!
        refresh_state!
        state_obj = State.new(@state)
        break if predicate.call(state_obj)

        adaptive_sleep(loop_count)
        loop_count += 1
      end
      @state
    end

    # Wait until output contains the given text
    def wait_for_text(text)
      deadline = monotonic + @timeout
      loop_count = 0
      loop do
        raise TimeoutError, "Timeout waiting for: #{text.inspect}" if monotonic > deadline

        read_available!
        found = @output_mutex.synchronize { @output_buffer.include?(text) }
        break if found

        adaptive_sleep(loop_count)
        loop_count += 1
      end
      refresh_state!
    end

    # Wait for output to stabilize (grid content unchanged for N milliseconds)
    def wait_for_stable(stable_ms: 300)
      deadline = monotonic + @timeout
      last_change = monotonic
      last_buffer_size = @output_mutex.synchronize { @output_buffer.bytesize }
      loop_count = 0

      loop do
        raise TimeoutError, "Timeout waiting for stable output" if monotonic > deadline

        read_available!
        current_buffer_size = @output_mutex.synchronize { @output_buffer.bytesize }
        process_alive = process_alive?

        if current_buffer_size != last_buffer_size
          last_buffer_size = current_buffer_size
          last_change = monotonic
        elsif !process_alive
          break
        elsif (monotonic - last_change) * 1000 >= stable_ms # rubocop:disable Lint/DuplicateBranch
          break
        end

        adaptive_sleep(loop_count)
        loop_count += 1
      end
      refresh_state!
    end

    # Wait until the process finishes
    def wait_for_exit
      @wait_thr&.value
    end

    # Get the process exit status (nil if still running)
    def exitstatus
      return nil unless @wait_thr

      status = @wait_thr.value
      status&.exitstatus
    rescue NoMethodError
      nil
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
      refresh_state!
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

    # Search for text or regex pattern in the current terminal state.
    # Delegates to TansParser::State#find_text.
    # Supports match modes: :partial (default, substring), :exact, :regex.
    def find_text(pattern, match: :partial)
      TUITD::State.new(state_data).find_text(pattern, match: match)
    end

    # Return a snapshot of the current terminal state as a TUITD::State object.
    # Can be compared later with match_snapshot or State#diff.
    def snapshot
      TUITD::State.new(state_data)
    end

    # Start video recording (requires ffmpeg).
    # Options: framerate (default 30), codec (default "libx264"), quality ("high"/"medium"/"low").
    def start_recording(path, framerate: 30, codec: "libx264", quality: "high")
      raise Error, "Recording already in progress" if recording?

      require_relative "video_recorder"
      @recorder = VideoRecorder.new(path, driver: self, framerate: framerate,
                                          codec: codec, quality: quality,)
      @recorder.start
      path
    end

    # Stop video recording and finalize the video file.
    # Returns the output path, or nil if not recording.
    def stop_recording
      return nil unless @recorder

      path = @recorder.stop
      @recorder = nil
      path
    end

    # Is video recording currently active?
    def recording?
      @recorder&.recording? || false
    end

    # Close the driver and clean up
    def close
      stop_recording
      _stop_reader_thread

      # Kill the process if still running
      if @pid
        begin
          if Process.waitpid(@pid, Process::WNOHANG).nil?
            begin
              Process.kill("TERM", @pid)
            rescue StandardError
              nil
            end
            sleep 0.05
            begin
              Process.kill("KILL", @pid)
            rescue StandardError
              nil
            end
          end
        rescue Errno::ECHILD
          # Already reaped by Process.detach
        end
      end
      begin
        @stdin&.close
      rescue StandardError
        nil
      end
      begin
        @stdout&.close
      rescue StandardError
        nil
      end
      @stdin = @stdout = @pid = nil
    end

    private

    def _start_reader_thread
      @reader_running = true
      @reader_thread = Thread.new do
        loop_count = 0
        loop do
          break unless @reader_running

          begin
            read_available!
          rescue IOError, Errno::EIO
            break
          end
          adaptive_sleep(loop_count)
          loop_count += 1
        end
      end
    end

    def _stop_reader_thread
      @reader_running = false
      return unless @reader_thread

      @reader_thread.join(1)
      begin
        @reader_thread.kill
      rescue StandardError
        nil
      end
      @reader_thread = nil
    end

    def sanitize_env(env)
      env.reject { |k, _| FORBIDDEN_ENV.include?(k.to_s.upcase) }
    end

    def ensure_running!
      raise Error, "Driver not started. Call #start first." if @stdin.nil?
      raise Error, "Process exited (status: #{@wait_thr&.value&.exitstatus})" unless @wait_thr&.alive?
    end

    def adaptive_sleep(loop_count)
      interval = if @poll_interval
                   @poll_interval
                 elsif loop_count < 40   # ~0-2s: 10ms
                   0.01
                 elsif loop_count < 160  # ~2-5s: 25ms
                   0.025
                 elsif loop_count < 260  # ~5-10s: 50ms
                   0.05
                 else # 10s+: 100ms
                   0.1
                 end
      sleep interval
    end

    def read_available!
      return false unless @stdout

      data = @stdout.read_nonblock(4096)

      @output_mutex.synchronize do
        @output_buffer << data
        @output_buffer = @output_buffer[-MAX_BUFFER_SIZE..] if @output_buffer.bytesize > MAX_BUFFER_SIZE
      end

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

    def parse_grid_snapshot
      @output_mutex.synchronize do
        ANSIParser.parse(@output_buffer, @rows, @cols)[:rows]
      end
    end

    def process_alive?
      return false unless @pid

      Process.waitpid(@pid, Process::WNOHANG).nil?
    rescue Errno::ECHILD
      false
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end

  class TimeoutError < Error; end
end
# rubocop:enable Metrics/ClassLength, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists
# rubocop:enable Naming/PredicateMethod
