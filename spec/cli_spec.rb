require "fileutils"
require "spec_helper"

RSpec.describe TUITD::CLI do
  describe ".run" do
    it "fails on unknown subcommand" do
      expect {
        described_class.run(["nonexistent_command"])
      }.to raise_error(SystemExit) { |e| expect(e.success?).to be false }
    end

    it "fails on capture without arguments" do
      expect {
        described_class.run(["capture"])
      }.to raise_error(SystemExit) { |e| expect(e.success?).to be false }
    end

    it "fails on test without arguments" do
      expect {
        described_class.run(["test"])
      }.to raise_error(SystemExit) { |e| expect(e.success?).to be false }
    end

    it "fails on run without arguments" do
      expect {
        described_class.run(["run"])
      }.to raise_error(SystemExit) { |e| expect(e.success?).to be false }
    end

    it "fails on drive without arguments" do
      expect {
        described_class.run(["drive"])
      }.to raise_error(SystemExit) { |e| expect(e.success?).to be false }
    end

    it "prints version with --version" do
      output = cli_run_capturing_stdout_and_exit(["--version"])
      expect(output).to match(/tui-td \d+\.\d+\.\d+/)
    end

    it "prints CLI help with --help" do
      output = cli_run_capturing_stdout_and_exit(["--help"])
      expect(output).to include("Usage: tui-td")
    end

    it "aborts on unknown help topic" do
      expect {
        described_class.run(["help", "nonexistent"])
      }.to raise_error(SystemExit) { |e| expect(e.success?).to be false }
    end

    it "prints test help" do
      output = cli_run_capturing_stdout_and_exit(["help", "test"])
      expect(output).to include("test")
    end

    it "prints rspec help" do
      output = cli_run_capturing_stdout_and_exit(["help", "rspec"])
      expect(output).to include("RSpec")
    end
  end

  describe "capture command" do
    it "captures output in text format by default" do
      output = cli_run_capturing_stdout(["capture", "echo", "hello from cli"])
      expect(output).to include("hello from cli")
    end

    it "captures output in JSON format" do
      output = cli_run_capturing_stdout(["--json", "capture", "echo", "test"])
      parsed = JSON.parse(output)
      expect(parsed).to have_key("rows")
      expect(parsed).to have_key("cursor")
      expect(parsed).to have_key("size")
    end

    it "captures output in pretty JSON format" do
      output = cli_run_capturing_stdout(["--pretty", "capture", "echo", "test"])
      expect(output).to include("\n  ")
      parsed = JSON.parse(output)
      expect(parsed).to have_key("rows")
    end

    it "supports custom rows and cols via global flags" do
      output = cli_run_capturing_stdout(["--rows", "5", "--cols", "40", "--json", "capture", "echo", "ok"])
      parsed = JSON.parse(output)
      expect(parsed["size"]).to eq({ "rows" => 5, "cols" => 40 })
    end

    it "supports --timeout flag" do
      output = cli_run_capturing_stdout(["--timeout", "5", "capture", "echo", "ok"])
      expect(output).to include("ok")
    end

    it "generates a screenshot with --screenshot flag" do
      path = "/tmp/tui_td_test_cli_screenshot.png"
      FileUtils.rm_f(path)
      cli_run_capturing_stdout(["--screenshot", path, "--timeout", "5", "capture", "echo", "hello"])
      expect(File.exist?(path)).to be true
      expect(File.size(path)).to be > 0
    ensure
      FileUtils.rm_f(path) if path
    end

    it "generates HTML with --html flag" do
      path = "/tmp/tui_td_test_cli_output.html"
      FileUtils.rm_f(path)
      output = cli_run_capturing_stdout(["--html", path, "--timeout", "5", "capture", "echo", "hello"])
      expect(output).to include("HTML saved")
      expect(File.exist?(path)).to be true
      expect(File.size(path)).to be > 0
    ensure
      FileUtils.rm_f(path) if path
    end

    it "accepts short flags (-r, -c)" do
      output = cli_run_capturing_stdout(["-r", "5", "-c", "40", "--json", "capture", "echo", "ok"])
      parsed = JSON.parse(output)
      expect(parsed["size"]).to eq({ "rows" => 5, "cols" => 40 })
    end
  end

  describe "global flags" do
    it "handles flags before command" do
      output = cli_run_capturing_stdout(["--timeout", "5", "capture", "echo", "ok"])
      expect(output).to include("ok")
    end
  end

  def cli_run_capturing_stdout(argv)
    original = $stdout
    $stdout = StringIO.new
    described_class.run(argv)
    $stdout.string
  ensure
    $stdout = original
  end

  def cli_run_capturing_stdout_and_exit(argv)
    original = $stdout
    $stdout = StringIO.new
    described_class.run(argv)
    $stdout.string
  rescue SystemExit
    $stdout.string
  ensure
    $stdout = original
  end
end
