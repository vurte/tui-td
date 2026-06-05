# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "spec_helper"
require "tui_td/test_runner"

RSpec.describe TUITD::TestRunner do
  def run_plan(plan)
    described_class.new(plan).run
  end

  describe "basic flow" do
    it "runs a simple echo test successfully" do
      plan = {
        name: "echo test",
        rows: 10,
        cols: 60,
        timeout: 10,
        steps: [
          { start: "echo hello world" },
          { wait_for_stable: true },
          { assert_text: "hello" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:passed]).to be true
      expect(result[:results].size).to eq(4)
      expect(result[:results].all? { |r| r[:passed] }).to be true
    end

    it "fails when text not found" do
      plan = {
        name: "failing test",
        steps: [
          { start: "echo hello" },
          { wait_for_stable: true },
          { assert_text: "NONEXISTENT" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:passed]).to be false
      expect(result[:results][2][:passed]).to be false
      expect(result[:results][2][:message]).to include("NOT found")
    end

    it "returns step names and messages" do
      plan = {
        name: "echo",
        steps: [
          { start: "echo hi" },
          { wait_for_stable: true },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:name]).to eq("echo")
      expect(result[:results][0][:step]).to eq("start")
      expect(result[:results][0][:message]).to include("echo hi")
    end
  end

  describe "send and send_key" do
    it "sends text" do
      # Use a command that reads from stdin and echoes it back
      plan = {
        name: "send test",
        rows: 10,
        cols: 60,
        timeout: 10,
        steps: [
          { start: "cat" },
          { send: "hello\n" },
          { wait_for_text: "hello" },
          { send_key: "ctrl_c" },
          # wait for exit after ctrl_c, but the process may buffer
          { wait_for_stable: true },
          { close: true },
        ],
      }
      result = run_plan(plan)
      # cat may not exit cleanly; just check assertions didn't crash
      expect(result[:results].size).to be >= 5
    end
  end

  describe "color assertions" do
    it "asserts foreground color" do
      plan = {
        name: "fg test",
        rows: 5,
        cols: 20,
        steps: [
          { start: "printf '\e[32mgreen\e[0m'" },
          { wait_for_stable: true },
          { assert_fg: [0, 0], is: "green" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
    end

    it "fails on wrong foreground color" do
      plan = {
        name: "fg fail test",
        rows: 5,
        cols: 20,
        steps: [
          { start: "printf '\e[32mgreen\e[0m'" },
          { wait_for_stable: true },
          { assert_fg: [0, 0], is: "red" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be false
    end

    it "asserts background color" do
      plan = {
        name: "bg test",
        rows: 5,
        cols: 20,
        steps: [
          { start: "printf '\e[44mblue bg\e[0m'" },
          { wait_for_stable: true },
          { assert_bg: [0, 0], is: "blue" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
    end

    it "asserts style" do
      plan = {
        name: "style test",
        rows: 5,
        cols: 20,
        steps: [
          { start: "printf '\e[1mbold\e[0m'" },
          { wait_for_stable: true },
          { assert_style: [0, 0], bold: true },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
    end
  end

  describe "screenshot step" do
    it "saves a screenshot" do
      path = "/tmp/tui_td_runner_test_#{Process.pid}.png"
      plan = {
        name: "screenshot test",
        rows: 3,
        cols: 10,
        steps: [
          { start: "echo screenshot" },
          { wait_for_stable: true },
          { screenshot: path },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
      expect(File.exist?(path)).to be true
      expect(File.size(path)).to be > 0
    ensure
      File.delete(path) if path && File.exist?(path)
    end
  end

  describe "unknown action" do
    it "fails for unknown actions" do
      plan = {
        name: "bad step",
        steps: [
          { start: "echo test" },
          { wait_for_stable: true },
          { bogus_action: "whatever" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:passed]).to be false
      expect(result[:results][2][:passed]).to be false
      expect(result[:results][2][:message]).to include("Unknown action")
    end
  end

  describe "error handling" do
    it "fails when no start step precedes actions" do
      plan = {
        name: "no start",
        steps: [
          { assert_text: "hello" },
        ],
      }
      result = run_plan(plan)
      expect(result[:passed]).to be false
      expect(result[:results][0][:message]).to include("No session")
    end

    it "gracefully handles command that exits immediately" do
      plan = {
        name: "fast exit",
        rows: 5,
        cols: 20,
        timeout: 5,
        steps: [
          { start: "true" },
          { wait_for_stable: true },
          { close: true },
        ],
      }
      result = run_plan(plan)
      # Should not crash; wait_for_stable may fail or succeed depending on timing
      expect(result[:results].size).to eq(3)
    end
  end

  describe "JSON string input" do
    it "accepts JSON string" do
      json = JSON.generate({
                             name: "json string",
                             steps: [
                               { start: "echo json" },
                               { wait_for_stable: true },
                               { assert_text: "json" },
                               { close: true },
                             ],
                           })
      result = described_class.new(json).run
      expect(result[:passed]).to be true
    end
  end

  describe "assert_not_text" do
    it "passes when text is absent" do
      plan = {
        name: "not text pass",
        rows: 5,
        cols: 20,
        steps: [
          { start: "echo hello" },
          { wait_for_stable: true },
          { assert_not_text: "NONEXISTENT" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
    end

    it "fails when text is present" do
      plan = {
        name: "not text fail",
        rows: 5,
        cols: 20,
        steps: [
          { start: "echo hello world" },
          { wait_for_stable: true },
          { assert_not_text: "hello" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be false
      expect(result[:results][2][:message]).to include("should not be")
    end
  end

  describe "assert_regex" do
    it "passes when regex matches" do
      plan = {
        name: "regex pass",
        rows: 5,
        cols: 20,
        steps: [
          { start: "echo error: something failed" },
          { wait_for_stable: true },
          { assert_regex: "error|fail|warn" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
    end

    it "fails when regex does not match" do
      plan = {
        name: "regex fail",
        rows: 5,
        cols: 20,
        steps: [
          { start: "echo all good" },
          { wait_for_stable: true },
          { assert_regex: "error|fail" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be false
      expect(result[:results][2][:message]).to include("did not match")
    end

    it "matches regex special characters" do
      plan = {
        name: "regex special",
        rows: 5,
        cols: 20,
        steps: [
          { start: "echo HTTP 500" },
          { wait_for_stable: true },
          { assert_regex: "\\d{3}" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
    end
  end

  describe "html step" do
    it "saves HTML output" do
      path = "/tmp/tui_td_html_test_#{Process.pid}.html"
      plan = {
        name: "html test",
        rows: 3,
        cols: 10,
        steps: [
          { start: "echo html" },
          { wait_for_stable: true },
          { html: path },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
      expect(File.exist?(path)).to be true
      expect(File.read(path)).to include("<!DOCTYPE html>")
    ensure
      File.delete(path) if path && File.exist?(path)
    end
  end

  describe "hooks" do
    it "runs before_all steps before main steps" do
      plan = {
        name: "hooks test",
        rows: 5,
        cols: 20,
        timeout: 10,
        before_all: [
          { start: "echo setup" },
          { wait_for_stable: true },
          { assert_text: "setup" },
        ],
        steps: [
          { assert_text: "setup" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:passed]).to be true
      # Total results: 3 before_all + 2 main = 5
      expect(result[:results].size).to eq(5)
    end

    it "runs after_all steps after main steps" do
      plan = {
        name: "after_all test",
        rows: 5,
        cols: 20,
        timeout: 10,
        steps: [
          { start: "echo test" },
          { wait_for_stable: true },
          { assert_text: "test" },
        ],
        after_all: [
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:passed]).to be true
      # Results include after_all step
      expect(result[:results].last[:step]).to eq("close")
    end
  end

  describe "invalid JSON" do
    it "raises Error with descriptive message" do
      expect { described_class.new("not json") }.to raise_error(TUITD::Error, /Invalid JSON/)
    end
  end

  describe "invalid regex" do
    it "returns fail result for malformed regex" do
      plan = {
        name: "bad regex",
        rows: 5,
        cols: 20,
        steps: [
          { start: "echo test" },
          { wait_for_stable: true },
          { assert_regex: "[[" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be false
      expect(result[:results][2][:message]).to include("Invalid regex")
    end
  end

  describe "on_step callback" do
    it "invokes callback for each step" do
      steps_seen = []
      on_step = ->(info) { steps_seen << info[:action] }

      plan = {
        name: "callback test",
        rows: 5,
        cols: 20,
        timeout: 10,
        steps: [
          { start: "echo callback" },
          { wait_for_stable: true },
          { assert_text: "callback" },
          { close: true },
        ],
      }
      runner = described_class.new(plan, on_step: on_step)
      runner.run
      expect(steps_seen).to eq(%w[start wait_for_stable assert_text close])
    end
  end

  describe "exit code" do
    it "waits for process exit and asserts exit status 0" do
      plan = {
        name: "exit 0",
        rows: 5,
        cols: 20,
        timeout: 10,
        steps: [
          { start: "true" },
          { wait_for_exit: true },
          { assert_exit: 0 },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:passed]).to be true
      expect(result[:results][2][:passed]).to be true
    end

    it "fails when exit status does not match" do
      plan = {
        name: "exit 1",
        rows: 5,
        cols: 20,
        timeout: 10,
        steps: [
          { start: "bash -c 'exit 2'" },
          { wait_for_exit: true },
          { assert_exit: 0 },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:passed]).to be false
      expect(result[:results][2][:message]).to include("Exit status 2")
    end
  end

  describe "selector assertions" do
    it "asserts button exists by text" do
      plan = {
        name: "button test",
        rows: 5,
        cols: 30,
        steps: [
          { start: "printf '[ OK ]'" },
          { wait_for_stable: true },
          { assert_button: "OK" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
    end

    it "fails assert_button when button not found" do
      plan = {
        name: "button fail",
        rows: 5,
        cols: 30,
        steps: [
          { start: "echo hello" },
          { wait_for_stable: true },
          { assert_button: "OK" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be false
    end

    it "asserts dialog exists" do
      plan = {
        name: "dialog test",
        rows: 5,
        cols: 30,
        steps: [
          { start: "printf '\n┌──┐\n│OK│\n└──┘'" },
          { wait_for_stable: true },
          { assert_dialog: true },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
    end

    it "asserts checkbox with checked state" do
      plan = {
        name: "checkbox test",
        rows: 5,
        cols: 30,
        steps: [
          { start: "printf '[x] Enable'" },
          { wait_for_stable: true },
          { assert_checkbox: "Enable", checked: true },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
    end

    it "asserts role generically" do
      plan = {
        name: "role test",
        rows: 5,
        cols: 30,
        steps: [
          { start: "printf '(Cancel)'" },
          { wait_for_stable: true },
          { assert_role: "Cancel", role: "button" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
    end

    it "asserts input field" do
      plan = {
        name: "input test",
        rows: 3,
        cols: 30,
        steps: [
          { start: "printf '[________]'" },
          { wait_for_stable: true },
          { assert_input: true },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
    end

    it "asserts label" do
      plan = {
        name: "label test",
        rows: 3,
        cols: 20,
        steps: [
          { start: "printf 'Username:'" },
          { wait_for_stable: true },
          { assert_label: "Username" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
    end

    it "asserts menu bar" do
      plan = {
        name: "menu test",
        rows: 3,
        cols: 40,
        steps: [
          { start: "printf 'File    Edit    View'" },
          { wait_for_stable: true },
          { assert_menu: true },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
    end

    it "asserts tabs" do
      plan = {
        name: "tab test",
        rows: 3,
        cols: 30,
        steps: [
          { start: "printf '[File] [Edit] [View]'" },
          { wait_for_stable: true },
          { assert_tab: "File" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
    end

    it "asserts status bar" do
      plan = {
        name: "statusbar test",
        rows: 5,
        cols: 30,
        steps: [
          { start: "ruby -e 'print \"\\n\" * 4; print \"\\e[0;44mStatus: idle\\e[0m\"'" },
          { wait_for_stable: true },
          { assert_statusbar: true },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
    end

    it "asserts progress bar" do
      plan = {
        name: "progress test",
        rows: 3,
        cols: 30,
        steps: [
          { start: "printf '[##########         ] 50%%'" },
          { wait_for_stable: true },
          { assert_progress_bar: true },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:results][2][:passed]).to be true
    end
  end

  describe "snapshot steps" do
    let(:snapshot_dir) { Dir.mktmpdir("tui_td_test_snap") }

    before { TUITD.configure { |c| c.snapshot_dir = snapshot_dir } }

    after do
      FileUtils.rm_rf(snapshot_dir)
      TUITD.instance_variable_set(:@configuration, nil)
    end

    it "snapshot step saves to disk" do
      plan = {
        name: "snapshot save test",
        rows: 3,
        cols: 20,
        steps: [
          { start: "echo hello" },
          { wait_for_stable: true },
          { snapshot: "test_snap1" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:passed]).to be true
      expect(File).to exist(File.join(snapshot_dir, "test_snap1.json"))
    end

    it "assert_snapshot creates on first run" do
      plan = {
        name: "first run create",
        rows: 3,
        cols: 20,
        steps: [
          { start: "echo first_run" },
          { wait_for_stable: true },
          { assert_snapshot: "first_run_create" },
          { close: true },
        ],
      }
      result = run_plan(plan)
      expect(result[:passed]).to be true
      expect(File).to exist(File.join(snapshot_dir, "first_run_create.json"))
    end

    it "assert_snapshot matches saved snapshot" do
      TUITD::Snapshot.new("match_test", type: :text, snapshot_dir: snapshot_dir)
      plan = {
        name: "save first",
        rows: 3,
        cols: 20,
        steps: [
          { start: "echo match_me" },
          { wait_for_stable: true },
          { snapshot: "match_test" },
          { close: true },
        ],
      }
      run_plan(plan)

      plan2 = {
        name: "assert match",
        rows: 3,
        cols: 20,
        steps: [
          { start: "echo match_me" },
          { wait_for_stable: true },
          { assert_snapshot: "match_test" },
          { close: true },
        ],
      }
      result = run_plan(plan2)
      expect(result[:passed]).to be true
    end
  end
end
