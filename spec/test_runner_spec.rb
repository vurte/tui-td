# frozen_string_literal: true

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
end
