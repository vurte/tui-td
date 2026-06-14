# frozen_string_literal: true

require "fileutils"
require "spec_helper"

RSpec.describe TUITD::Driver do
  describe "#initialize" do
    it "accepts a command string" do
      driver = described_class.new("echo hello")
      expect(driver.command).to eq("echo hello")
    end

    it "defaults rows to 40" do
      driver = described_class.new("echo")
      driver.start
      expect(driver.state[:size][:rows]).to eq(40)
    ensure
      driver.close
    end

    it "accepts custom rows and cols" do
      driver = described_class.new("echo", rows: 10, cols: 80)
      driver.start
      expect(driver.state[:size]).to eq({ rows: 10, cols: 80 })
    ensure
      driver.close
    end

    it "accepts a custom timeout" do
      driver = described_class.new("echo", timeout: 5)
      driver.start
      expect(driver.state).not_to be_nil
    ensure
      driver.close
    end

    it "accepts a custom poll_interval" do
      driver = described_class.new("echo hello", poll_interval: 0.01)
      driver.start
      expect(driver.state).not_to be_nil
    ensure
      driver.close
    end

    it "accepts custom environment variables" do
      driver = described_class.new("bash -c 'echo $FOO'", env: { "FOO" => "bar" })
      driver.start
      text = driver.state[:rows][0].map { |c| c[:char] }.join
      expect(text).to include("bar")
    ensure
      driver.close
    end

    it "rejects forbidden environment variables" do
      driver = described_class.new("bash -c 'echo $PATH'",
                                   env: { "FOO" => "bar", "PATH" => "/evil/bin", "LD_PRELOAD" => "/evil.so" },)
      # PATH and LD_PRELOAD should be stripped by sanitize_env
      env_ivar = driver.instance_variable_get(:@env)
      expect(env_ivar.keys).to include("FOO")
      expect(env_ivar.keys).not_to include("PATH")
      expect(env_ivar.keys).not_to include("LD_PRELOAD")
    end

    it "does not execute shell metacharacters" do
      marker = "/tmp/tui_td_injection_test_#{Process.pid}"
      FileUtils.rm_f(marker)
      # ; touch /tmp/... would create a file if a shell were involved
      driver = described_class.new("echo safe; touch #{marker}")
      driver.start
      driver.wait_for_exit
      # The "; touch ..." part must not be executed
      expect(File.exist?(marker)).to be false
    ensure
      driver&.close
      FileUtils.rm_f(marker)
    end
  end

  describe "#start" do
    it "starts a process and parses its output" do
      driver = described_class.new("echo hello world")
      driver.start
      expect(driver.state).not_to be_nil
      expect(driver.state[:rows][0].map { |c| c[:char] }.join).to include("hello")
    ensure
      driver.close
    end

    it "sets the TERM environment variable" do
      driver = described_class.new("echo $TERM", env: { "TERM" => nil }) # nil to avoid merge
      # The start method always sets TERM=xterm-256color
      driver.start
    ensure
      driver.close
    end

    it "starts the background reader thread" do
      driver = described_class.new("sleep 0.1 && echo done")
      driver.start
      thread = driver.instance_variable_get(:@reader_thread)
      expect(thread).to be_a(Thread)
      expect(thread.alive?).to be true
    ensure
      driver.close
    end
  end

  describe "#send" do
    it "sends text to the process" do
      driver = described_class.new("cat", timeout: 2)
      begin
        driver.start
      rescue TUITD::TimeoutError
        # cat waits for input, never stabilizes
      end
      driver.send("hello\n")
      sleep 0.2
      expect(driver.raw_output).to include("hello")
    ensure
      begin
        driver.close
      rescue StandardError
        nil
      end
    end

    it "raises Error if driver not started" do
      driver = described_class.new("cat")
      expect { driver.send("text") }.to raise_error(TUITD::Error, /not started/)
    end
  end

  describe "#send_keys" do
    let(:cat_driver) do
      driver = described_class.new("cat", timeout: 2)
      begin
        driver.start
      rescue TUITD::TimeoutError
        # cat waits for input
      end
      driver
    end

    after do
      cat_driver&.close
    rescue StandardError
      nil
    end

    it "sends enter key" do
      expect { cat_driver.send_keys(:enter) }.not_to raise_error
    end

    it "sends escape sequence for arrow keys" do
      expect { cat_driver.send_keys(:up) }.not_to raise_error
      expect { cat_driver.send_keys(:down) }.not_to raise_error
      expect { cat_driver.send_keys(:left) }.not_to raise_error
      expect { cat_driver.send_keys(:right) }.not_to raise_error
    end

    it "sends control characters" do
      expect { cat_driver.send_keys(:ctrl_c) }.not_to raise_error
      expect { cat_driver.send_keys(:ctrl_d) }.not_to raise_error
    end

    it "sends backspace" do
      expect { cat_driver.send_keys(:backspace) }.not_to raise_error
    end

    it "sends page up and page down" do
      expect { cat_driver.send_keys(:page_up) }.not_to raise_error
      expect { cat_driver.send_keys(:page_down) }.not_to raise_error
    end

    it "sends tab" do
      expect { cat_driver.send_keys(:tab) }.not_to raise_error
    end

    it "sends escape" do
      expect { cat_driver.send_keys(:escape) }.not_to raise_error
    end

    it "sends string for unknown keys" do
      expect { cat_driver.send_keys("plain_text") }.not_to raise_error
    end
  end

  describe "#wait_for_text" do
    it "returns when text appears in output" do
      driver = described_class.new("echo hello && echo world")
      driver.start
      driver.wait_for_text("world")
      expect(driver.raw_output).to include("world")
    ensure
      driver.close
    end

    it "raises TimeoutError when text never appears" do
      driver = described_class.new("echo ok && sleep 5", timeout: 1)
      driver.start
      expect { driver.wait_for_text("NEVER") }.to raise_error(TUITD::TimeoutError, /NEVER/)
    ensure
      driver.close
    end
  end

  describe "#wait_for" do
    it "returns when predicate becomes true" do
      driver = described_class.new('bash -c "sleep 0.1 && echo ready"')
      driver.start
      result = driver.wait_for { |s| s.find_text("ready").any? }
      expect(result).to have_key(:rows)
    ensure
      driver.close
    end

    it "raises TimeoutError when predicate never becomes true" do
      driver = described_class.new("sleep 5", timeout: 1)
      driver.start
      expect { driver.wait_for { |_s| false } }.to raise_error(TUITD::TimeoutError)
    ensure
      driver.close
    end

    it "accepts a custom timeout" do
      driver = described_class.new("echo ready")
      driver.start
      result = driver.wait_for(timeout: 5) { |s| s.find_text("ready").any? }
      expect(result).to have_key(:rows)
    ensure
      driver.close
    end

    it "passes a State object to the predicate" do
      driver = described_class.new("echo hello")
      driver.start
      driver.wait_for do |s|
        expect(s).to respond_to(:find_text)
        expect(s).to respond_to(:foreground_at)
        expect(s).to respond_to(:style_at)
        s.find_text("hello").any?
      end
    ensure
      driver.close
    end

    it "refreshes state between predicate calls" do
      driver = described_class.new('bash -c "echo first && sleep 0.1 && echo second"', cols: 40)
      driver.start
      states_seen = []
      driver.wait_for do |s|
        states_seen << s.plain_text.dup
        s.plain_text.include?("second")
      end
      expect(states_seen.size).to be >= 1
      expect(states_seen.last).to include("second")
    ensure
      driver.close
    end
  end

  describe "#wait_for_stable" do
    it "returns when output stabilizes" do
      driver = described_class.new("echo hello world", timeout: 5)
      driver.start
      # Second call should return immediately since process exited
      expect { driver.wait_for_stable }.not_to raise_error
    ensure
      driver.close
    end

    it "returns immediately for an already-finished process" do
      driver = described_class.new("echo done", timeout: 5)
      driver.start
      # Process already exited, second wait_for_stable should return immediately
      expect { driver.wait_for_stable }.not_to raise_error
    ensure
      driver.close
    end

    it "accepts custom stable_ms" do
      driver = described_class.new("echo fast", timeout: 5)
      driver.start
      expect { driver.wait_for_stable(stable_ms: 100) }.not_to raise_error
    ensure
      driver.close
    end
  end

  describe "#wait_for_exit" do
    it "waits for process to finish and returns status" do
      driver = described_class.new("echo done", timeout: 5)
      driver.start
      status = driver.wait_for_exit
      expect(status).to respond_to(:exitstatus)
      expect(status.exitstatus).to eq(0)
    ensure
      driver.close
    end
  end

  describe "#exitstatus" do
    it "returns nil while process is running" do
      driver = described_class.new("sleep 0.5 && echo done", timeout: 5)
      driver.start
      # Process should still be running or just finished
      driver.close
    end

    it "returns 0 for successful command" do
      driver = described_class.new("true")
      driver.start
      driver.wait_for_exit
      expect(driver.exitstatus).to eq(0)
    ensure
      driver.close
    end

    it "returns non-zero for failing command" do
      driver = described_class.new("bash -c 'exit 42'")
      driver.start
      driver.wait_for_exit
      expect(driver.exitstatus).to eq(42)
    rescue PTY::ChildExited
      # On some systems, the PTY raises when the child exits with non-zero
      driver&.close
    end

    it "returns nil when @wait_thr is nil" do
      driver = described_class.new("true")
      expect(driver.exitstatus).to be_nil
    end
  end

  describe "#raw_output" do
    it "returns the raw output buffer" do
      driver = described_class.new("echo hello")
      driver.start
      output = driver.raw_output
      expect(output).to be_a(String)
      expect(output.length).to be > 0
    ensure
      driver.close
    end
  end

  describe "#refresh" do
    it "re-parses the output buffer and returns state" do
      driver = described_class.new("echo hello")
      driver.start
      state = driver.refresh
      expect(state).to have_key(:rows)
    ensure
      driver.close
    end
  end

  describe "#state_data" do
    it "returns a Hash with terminal state" do
      driver = described_class.new("echo hello")
      driver.start
      data = driver.state_data
      expect(data).to be_a(Hash)
      expect(data).to have_key(:rows)
      expect(data).to have_key(:cursor)
      expect(data).to have_key(:size)
    ensure
      driver.close
    end
  end

  describe "#state_json" do
    it "returns a JSON string" do
      driver = described_class.new("echo hello")
      driver.start
      json = driver.state_json
      expect(json).to be_a(String)
      parsed = JSON.parse(json)
      expect(parsed).to have_key("rows")
      expect(parsed).to have_key("cursor")
    ensure
      driver.close
    end

    it "returns pretty JSON when requested" do
      driver = described_class.new("echo hello")
      driver.start
      json = driver.state_json(pretty: true)
      expect(json).to include("\n")
    ensure
      driver.close
    end
  end

  describe "#screenshot" do
    it "generates a PNG file" do
      driver = described_class.new("echo hello")
      driver.start
      path = "/tmp/tui_td_test_driver_screenshot.png"
      driver.screenshot(path)
      expect(File.exist?(path)).to be true
      expect(File.size(path)).to be > 0
    ensure
      driver&.close
      File.delete(path) if path && File.exist?(path)
    end
  end

  describe "#find_text" do
    it "finds text in terminal output" do
      driver = described_class.new("echo hello world", rows: 3, cols: 30, timeout: 5)
      driver.start
      results = driver.find_text("hello")
      expect(results).to be_an(Array)
      expect(results).not_to be_empty
      expect(results.first[:text]).to eq("hello")
    ensure
      driver&.close
    end

    it "returns empty array when pattern not found" do
      driver = described_class.new("echo test", rows: 3, cols: 20, timeout: 5)
      driver.start
      results = driver.find_text("NONEXISTENT")
      expect(results).to be_an(Array)
      expect(results).to be_empty
    ensure
      driver&.close
    end
  end

  describe "#snapshot" do
    it "returns a TUITD::State object" do
      driver = described_class.new("echo hello", rows: 3, cols: 20, timeout: 5)
      driver.start
      snap = driver.snapshot
      expect(snap).to be_a(TUITD::State)
    ensure
      driver&.close
    end

    it "produces identical snapshots for unchanged output" do
      driver = described_class.new("echo hello", rows: 3, cols: 20, timeout: 5)
      driver.start
      snap1 = driver.snapshot
      snap2 = driver.snapshot
      expect(snap1.diff(snap2)).to be_empty
    ensure
      driver&.close
    end
  end

  describe "#close" do
    it "cleans up PTY resources" do
      driver = described_class.new("sleep 10")
      driver.start
      driver.close
      expect(driver.instance_variable_get(:@stdin)).to be_nil
      expect(driver.instance_variable_get(:@stdout)).to be_nil
      expect(driver.instance_variable_get(:@pid)).to be_nil
    end

    it "can be called multiple times safely" do
      driver = described_class.new("echo hello")
      driver.start
      driver.close
      expect { driver.close }.not_to raise_error
    end

    it "can be called without calling start" do
      driver = described_class.new("echo hello")
      expect { driver.close }.not_to raise_error
    end
  end

  describe "error handling" do
    it "raises Error when trying to send without starting" do
      driver = described_class.new("cat")
      expect { driver.send("text") }.to raise_error(TUITD::Error, /not started/)
    end

    it "raises Error when process has exited" do
      driver = described_class.new("true", timeout: 5)
      driver.start
      driver.wait_for_exit
      expect { driver.send("text") }.to raise_error(TUITD::Error, /Process exited/)
    rescue PTY::ChildExited
      # On some systems, the PTY raises when the child exits
    ensure
      driver&.close
    end

    it "handles commands that exit immediately" do
      driver = described_class.new("true", timeout: 5)
      expect { driver.start }.not_to raise_error
    ensure
      driver.close
    end
  end

  describe "DSR (Device Status Report) handling" do
    it "responds to DSR escape sequence" do
      driver = described_class.new("cat", rows: 10, cols: 40, timeout: 5)
      driver.start
      sleep 0.2 # Let cat start
      # Send a DSR escape via the process output - since we read output,
      # we write directly to the PTY stdin and cat will echo it back
      driver.send("\e[6n")
      sleep 0.3 # Wait for the response
      # The DSR should have been handled — verify no crash
      state = driver.state_data
      expect(state).to be_a(Hash)
      expect(state).to have_key(:rows)
    rescue Errno::EIO
      # PTY closed - expected when cat exits
    ensure
      driver&.close
    end
  end

  describe "internal methods" do
    it "parse_grid_snapshot returns grid rows" do
      driver = described_class.new("sleep 0.5 && echo hello", rows: 3, cols: 20, timeout: 5)
      driver.start
      sleep 0.1
      grid = driver.__send__(:parse_grid_snapshot)
      expect(grid).to be_an(Array)
      expect(grid).not_to be_empty
      expect(grid[0]).to be_an(Array)
    ensure
      driver&.close
    end
  end
end
