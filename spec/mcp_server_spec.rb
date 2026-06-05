# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "spec_helper"

RSpec.describe TUITD::MCP::Server do
  let(:server) { described_class.new(rows: 10, cols: 40, timeout: 5) }

  def handle(method, params = {}, id: 1)
    request = { "jsonrpc" => "2.0", "method" => method, "id" => id, "params" => params }
    server.send(:handle_request, request)
  end

  describe "#handle_request" do
    describe "initialize" do
      it "returns server capabilities" do
        response = handle("initialize", { "protocolVersion" => "2024-11-05" })
        expect(response[:result][:protocolVersion]).to eq("2024-11-05")
        expect(response[:result][:serverInfo][:name]).to eq("tui-td")
        expect(response[:result][:serverInfo][:version]).to eq(TUITD::VERSION)
        expect(response[:result][:capabilities]).to have_key(:tools)
      end
    end

    describe "notifications/initialized" do
      it "returns nil (no response needed)" do
        response = handle("notifications/initialized")
        expect(response).to be_nil
      end
    end

    describe "tools/list" do
      it "returns the tool list" do
        response = handle("tools/list")
        tools = response[:result][:tools]
        expect(tools).to be_an(Array)
        expect(tools).not_to be_empty

        tool_names = tools.map { |t| t[:name] }
        expect(tool_names).to include("tui_start")
        expect(tool_names).to include("tui_send")
        expect(tool_names).to include("tui_send_key")
        expect(tool_names).to include("tui_wait_for_text")
        expect(tool_names).to include("tui_wait_for_stable")
        expect(tool_names).to include("tui_state")
        expect(tool_names).to include("tui_plain_text")
        expect(tool_names).to include("tui_screenshot")
        expect(tool_names).to include("tui_html_render")
        expect(tool_names).to include("tui_wait_for_exit")
        expect(tool_names).to include("tui_exit_status")
        expect(tool_names).to include("tui_find_text")
        expect(tool_names).to include("tui_find_elements")
        expect(tool_names).to include("tui_element_actions")
        expect(tool_names).to include("tui_diff")
        expect(tool_names).to include("tui_annotate_element")
        expect(tool_names).to include("tui_save_snapshot")
        expect(tool_names).to include("tui_assert_snapshot")
        expect(tool_names).to include("tui_close")
      end
    end

    describe "tools/call" do
      it "returns error for unknown tool" do
        response = handle("tools/call", { "name" => "nonexistent", "arguments" => {} })
        expect(response[:error][:code]).to eq(-32_602)
        expect(response[:error][:message]).to include("Unknown tool")
      end

      it "returns error when calling tui_send without start" do
        response = handle("tools/call", { "name" => "tui_send", "arguments" => { "text" => "hello" } })
        expect(response[:result][:content][0][:text]).to include("No TUI session active")
      end

      it "returns error for tui_send without text argument" do
        server.send(:call_tui_start, { "command" => "echo hello" })
        response = handle("tools/call", { "name" => "tui_send", "arguments" => {} })
        expect(response[:result][:content][0][:text]).to include("text")
      ensure
        server.send(:call_tui_close)
      end
    end

    describe "unknown methods" do
      it "ignores unknown notification methods" do
        response = handle("notifications/something")
        expect(response).to be_nil
      end

      it "returns error for unknown non-notification methods" do
        response = handle("unknown_method")
        expect(response[:error][:code]).to eq(-32_601)
        expect(response[:error][:message]).to include("Method not found")
      end
    end
  end

  describe "tool implementations" do
    describe "tui_start" do
      it "starts a process and returns its output" do
        result = server.send(:call_tui_start, { "command" => "echo hello world" })
        expect(result).to include("OK: Started")
        expect(result).to include("hello world")
      ensure
        server.send(:call_tui_close)
      end

      it "returns error when command is missing" do
        result = server.send(:call_tui_start, {})
        expect(result).to include("ERROR")
        expect(result).to include("command")
      end

      it "closes previous session before starting a new one" do
        server.send(:call_tui_start, { "command" => "echo first" })
        first = server.send(:call_tui_plain_text)
        server.send(:call_tui_start, { "command" => "echo second" })
        second = server.send(:call_tui_plain_text)
        expect(second).not_to eq(first)
      ensure
        server.send(:call_tui_close)
      end
    end

    describe "tui_send" do
      it "returns error when text is missing" do
        server.send(:call_tui_start, { "command" => "echo ok" })
        result = server.send(:call_tui_send, {})
        expect(result).to include("ERROR")
      ensure
        begin
          server.send(:call_tui_close)
        rescue StandardError
          nil
        end
      end
    end

    describe "tui_send_key" do
      it "returns error when key is missing" do
        server.send(:call_tui_start, { "command" => "echo ok" })
        result = server.send(:call_tui_send_key, {})
        expect(result).to include("ERROR")
      ensure
        begin
          server.send(:call_tui_close)
        rescue StandardError
          nil
        end
      end

      it "returns error when send_key used before start" do
        response = handle("tools/call", { "name" => "tui_send_key", "arguments" => { "key" => "enter" } })
        expect(response[:result][:content][0][:text]).to include("No TUI session active")
      end
    end

    describe "tui_wait_for_text" do
      it "waits for text in output" do
        server.send(:call_tui_start, { "command" => "echo hello && echo world" })
        result = server.send(:call_tui_wait_for_text, { "text" => "world" })
        expect(result).to include("hello")
      ensure
        server.send(:call_tui_close)
      end
    end

    describe "tui_wait_for_stable" do
      it "waits for output to stabilize" do
        server.send(:call_tui_start, { "command" => "echo done" })
        result = server.send(:call_tui_wait_for_stable, {})
        expect(result).to include("done")
      ensure
        server.send(:call_tui_close)
      end
    end

    describe "tui_state" do
      it "returns state in AI format by default" do
        server.send(:call_tui_start, { "command" => "echo hello" })
        result = server.send(:call_tui_state, {})
        parsed = JSON.parse(result)
        expect(parsed).to have_key("text")
        expect(parsed).to have_key("highlights")
        expect(parsed).to have_key("size")
      ensure
        server.send(:call_tui_close)
      end

      it "returns state in full format" do
        server.send(:call_tui_start, { "command" => "echo hello" })
        result = server.send(:call_tui_state, { "format" => "full" })
        parsed = JSON.parse(result)
        expect(parsed).to have_key("rows")
      ensure
        server.send(:call_tui_close)
      end

      it "returns state in text format" do
        server.send(:call_tui_start, { "command" => "echo hello" })
        result = server.send(:call_tui_state, { "format" => "text" })
        expect(result).to be_a(String)
      ensure
        server.send(:call_tui_close)
      end
    end

    describe "tui_plain_text" do
      it "returns plain text of terminal" do
        server.send(:call_tui_start, { "command" => "echo hello" })
        result = server.send(:call_tui_plain_text)
        expect(result).to include("hello")
      ensure
        server.send(:call_tui_close)
      end
    end

    describe "tui_screenshot" do
      it "saves a screenshot" do
        server.send(:call_tui_start, { "command" => "echo hello" })
        path = "/tmp/tui_td_mcp_test_screenshot.png"
        FileUtils.rm_f(path)
        result = server.send(:call_tui_screenshot, { "path" => path })
        expect(result).to include("OK: Screenshot saved")
        expect(File.exist?(path)).to be true
        expect(File.size(path)).to be > 0
        FileUtils.rm_f(path)
      ensure
        begin
          server.send(:call_tui_close)
        rescue StandardError
          nil
        end
        FileUtils.rm_f(path) if path && File.exist?(path)
      end
    end

    describe "tui_html_render" do
      it "returns inline HTML when no path given" do
        server.send(:call_tui_start, { "command" => "echo hello" })
        result = server.send(:call_tui_html_render, {})
        expect(result).to include("<!DOCTYPE html>")
      ensure
        server.send(:call_tui_close)
      end

      it "saves HTML to a file when path given" do
        server.send(:call_tui_start, { "command" => "echo hello" })
        path = "/tmp/tui_td_mcp_test_page.html"
        FileUtils.rm_f(path)
        result = server.send(:call_tui_html_render, { "path" => path })
        expect(result).to include("OK: HTML saved")
        expect(File.exist?(path)).to be true
        expect(File.size(path)).to be > 0
      ensure
        begin
          server.send(:call_tui_close)
        rescue StandardError
          nil
        end
        FileUtils.rm_f(path) if path
      end
    end

    describe "tui_screenshot path traversal" do
      it "rejects path outside /tmp" do
        server.send(:call_tui_start, { "command" => "echo hello" })
        path = "/etc/evil.png"
        expect { server.send(:call_tui_screenshot, { "path" => path }) }
          .to raise_error(TUITD::Error, /Output path must be under/)
      ensure
        begin
          server.send(:call_tui_close)
        rescue StandardError
          nil
        end
      end

      it "rejects dot-dot traversal" do
        server.send(:call_tui_start, { "command" => "echo hello" })
        path = "/tmp/../../../etc/evil.png"
        expect { server.send(:call_tui_screenshot, { "path" => path }) }
          .to raise_error(TUITD::Error, /Output path must be under/)
      ensure
        begin
          server.send(:call_tui_close)
        rescue StandardError
          nil
        end
      end
    end

    describe "tui_html_render path traversal" do
      it "rejects path outside /tmp" do
        server.send(:call_tui_start, { "command" => "echo hello" })
        path = "/etc/evil.html"
        expect { server.send(:call_tui_html_render, { "path" => path }) }
          .to raise_error(TUITD::Error, /Output path must be under/)
      ensure
        begin
          server.send(:call_tui_close)
        rescue StandardError
          nil
        end
      end
    end

    describe "tui_find_text" do
      it "finds text matching a pattern" do
        server.send(:call_tui_start, { "command" => "echo 'hello world' && echo 'testing 123'" })
        result = server.send(:call_tui_find_text, { "pattern" => "world" })
        expect(result).to include("Found")
        expect(result).to include("world")
      ensure
        server.send(:call_tui_close)
      end

      it "reports no matches" do
        server.send(:call_tui_start, { "command" => "echo hello" })
        result = server.send(:call_tui_find_text, { "pattern" => "NONEXISTENT" })
        expect(result).to include("No matches found")
      ensure
        server.send(:call_tui_close)
      end
    end

    describe "tui_find_elements" do
      it "detects buttons in terminal output" do
        server.send(:call_tui_start, { "command" => "echo '[ OK ]  (Cancel)  <Submit>'" })
        result = server.send(:call_tui_find_elements, { "role" => "button" })
        expect(result).to include("Found")
        expect(result).to include(":button")
        expect(result).to include("OK")
      ensure
        server.send(:call_tui_close)
      end

      it "detects checkboxes in terminal output" do
        server.send(:call_tui_start, { "command" => "echo '[x] Enable logging  [ ] Auto-save'" })
        result = server.send(:call_tui_find_elements, { "role" => "checkbox" })
        expect(result).to include(":checkbox")
        expect(result).to include("Enable logging")
        expect(result).to include("checked")
      ensure
        server.send(:call_tui_close)
      end

      it "filters elements by text" do
        server.send(:call_tui_start, { "command" => "echo '[ OK ]  (Cancel)'" })
        result = server.send(:call_tui_find_elements, { "text" => "Cancel" })
        expect(result).to include(":button")
        expect(result).to include("Cancel")
        expect(result).not_to include("OK")
      ensure
        server.send(:call_tui_close)
      end

      it "returns all elements when no filter given" do
        server.send(:call_tui_start, { "command" => "echo '[ OK ]'" })
        result = server.send(:call_tui_find_elements, {})
        expect(result).to include("Found")
      ensure
        server.send(:call_tui_close)
      end

      it "reports no elements when none match" do
        server.send(:call_tui_start, { "command" => "echo 'just plain text'" })
        result = server.send(:call_tui_find_elements, { "role" => "button" })
        expect(result).to include("No elements found")
      ensure
        server.send(:call_tui_close)
      end

      it "returns error when used before tui_start" do
        response = handle("tools/call", { "name" => "tui_find_elements", "arguments" => {} })
        expect(response[:result][:content][0][:text]).to include("No TUI session active")
      end

      it "filters by checked state" do
        server.send(:call_tui_start, { "command" => "echo '[x] OK  [ ] Cancel'" })
        result = server.send(:call_tui_find_elements, { "role" => "checkbox", "checked" => true })
        expect(result).to include("Found")
        expect(result).to include("OK")
        expect(result).to include("checked")
      ensure
        server.send(:call_tui_close)
      end

      it "detects new roles (input, label, menu, tab)" do
        server.send(:call_tui_start, { "command" => "echo 'File  Edit  View'" })
        result = server.send(:call_tui_find_elements, { "role" => "menu" })
        expect(result).to include(":menu")
      ensure
        server.send(:call_tui_close)
      end
    end

    describe "tui_find_text with match modes" do
      it "supports exact match mode" do
        server.send(:call_tui_start, { "command" => "echo hello" })
        result = server.send(:call_tui_find_text, { "pattern" => "hello", "match" => "exact" })
        expect(result).to include("Found")
      ensure
        server.send(:call_tui_close)
      end

      it "supports regex match mode" do
        server.send(:call_tui_start, { "command" => "echo 'hello world'" })
        result = server.send(:call_tui_find_text, { "pattern" => "[hw]+", "match" => "regex" })
        expect(result).to include("Found")
      ensure
        server.send(:call_tui_close)
      end
    end

    describe "tui_element_actions" do
      it "returns action hashes for a button" do
        server.send(:call_tui_start, { "command" => "echo '[ OK ]'" })
        result = server.send(:call_tui_element_actions, { "role" => "button" })
        expect(result).to include(":button")
        expect(result).to include("click")
        expect(result).to include("type")
        expect(result).to include("press_key")
      ensure
        server.send(:call_tui_close)
      end

      it "returns error for missing role" do
        server.send(:call_tui_start, { "command" => "echo test" })
        result = server.send(:call_tui_element_actions, {})
        expect(result).to include("ERROR")
      ensure
        server.send(:call_tui_close)
      end

      it "reports no element found" do
        server.send(:call_tui_start, { "command" => "echo 'just text'" })
        result = server.send(:call_tui_element_actions, { "role" => "button" })
        expect(result).to include("No button")
      ensure
        server.send(:call_tui_close)
      end

      it "returns error when used before tui_start" do
        response = handle("tools/call", { "name" => "tui_element_actions", "arguments" => { "role" => "button" } })
        expect(response[:result][:content][0][:text]).to include("No TUI session active")
      end
    end

    describe "tui_close" do
      it "closes the session" do
        server.send(:call_tui_start, { "command" => "echo ok" })
        result = server.send(:call_tui_close)
        expect(result).to include("OK: TUI session closed")
      end

      it "is safe to call without a session" do
        result = server.send(:call_tui_close)
        expect(result).to include("OK: TUI session closed")
      end
    end
  end

  describe "#error_response" do
    it "returns a properly formatted JSON-RPC error" do
      response = server.send(:error_response, 1, -32_600, "Invalid Request")
      expect(response[:jsonrpc]).to eq("2.0")
      expect(response[:id]).to eq(1)
      expect(response[:error][:code]).to eq(-32_600)
      expect(response[:error][:message]).to eq("Invalid Request")
    end
  end

  describe "tui_diff" do
    it "finds no differences for identical output" do
      server.send(:call_tui_start, { "command" => "echo hello" })
      snap = server.instance_variable_get(:@driver).state_data
      result = server.send(:call_tui_diff, { "snapshot" => snap })
      expect(result).to include("No differences")
    ensure
      server.send(:call_tui_close)
    end

    it "finds differences for changed output" do
      server.send(:call_tui_start, { "command" => "echo hello" })
      snap = server.instance_variable_get(:@driver).state_data
      server.send(:call_tui_close)

      server.send(:call_tui_start, { "command" => "echo world" })
      result = server.send(:call_tui_diff, { "snapshot" => snap })
      expect(result).to include("difference")
    ensure
      server.send(:call_tui_close)
    end

    it "returns error when used before tui_start" do
      response = handle("tools/call", { "name" => "tui_diff", "arguments" => { "snapshot" => {} } })
      expect(response[:result][:content][0][:text]).to include("No TUI session active")
    end
  end

  describe "tui_annotate_element" do
    it "annotates a region and shows in find_elements" do
      server.send(:call_tui_start, { "command" => "echo hello" })
      server.send(:call_tui_annotate_element,
                  { "role" => "button", "row" => 0, "col" => 0, "width" => 6, "height" => 1, "text" => "OK" })
      result = server.send(:call_tui_find_elements, { "role" => "button", "text" => "OK" })
      expect(result).to include(":button")
      expect(result).to include("OK")
    ensure
      server.send(:call_tui_close)
    end

    it "returns error when arguments missing" do
      server.send(:call_tui_start, { "command" => "echo test" })
      result = server.send(:call_tui_annotate_element, {})
      expect(result).to include("ERROR")
    ensure
      server.send(:call_tui_close)
    end
  end

  describe "tui_save_snapshot" do
    let(:snapshot_dir) { Dir.mktmpdir("tui_td_mcp_snap") }

    before { TUITD.configure { |c| c.snapshot_dir = snapshot_dir } }

    after do
      FileUtils.rm_rf(snapshot_dir)
      TUITD.instance_variable_set(:@configuration, nil)
    end

    it "saves a snapshot to disk" do
      server.send(:call_tui_start, { "command" => "echo hello" })
      result = server.send(:call_tui_save_snapshot, { "name" => "mcp_save_test" })
      expect(result).to include("OK: Snapshot")
      expect(result).to include("mcp_save_test")
    ensure
      server.send(:call_tui_close)
    end

    it "returns error when name is missing" do
      server.send(:call_tui_start, { "command" => "echo test" })
      result = server.send(:call_tui_save_snapshot, {})
      expect(result).to include("ERROR")
    ensure
      server.send(:call_tui_close)
    end
  end

  describe "tui_assert_snapshot" do
    let(:snapshot_dir) { Dir.mktmpdir("tui_td_mcp_assert") }

    before { TUITD.configure { |c| c.snapshot_dir = snapshot_dir } }

    after do
      FileUtils.rm_rf(snapshot_dir)
      TUITD.instance_variable_set(:@configuration, nil)
    end

    it "creates snapshot on first call" do
      server.send(:call_tui_start, { "command" => "echo first_assert" })
      result = server.send(:call_tui_assert_snapshot, { "name" => "mcp_assert1" })
      expect(result).to include("created")
    ensure
      server.send(:call_tui_close)
    end

    it "passes on matching output" do
      server.send(:call_tui_start, { "command" => "echo match_me" })
      snap = TUITD::Snapshot.new("mcp_assert_match", type: :text, snapshot_dir: snapshot_dir)
      snap.save(server.instance_variable_get(:@driver).state_data)
      server.send(:call_tui_close)

      server.send(:call_tui_start, { "command" => "echo match_me" })
      result = server.send(:call_tui_assert_snapshot, { "name" => "mcp_assert_match" })
      expect(result).to include("matches")
    ensure
      server.send(:call_tui_close)
    end

    it "reports mismatch" do
      server.send(:call_tui_start, { "command" => "echo baseline" })
      snap = TUITD::Snapshot.new("mcp_assert_mismatch", type: :text, snapshot_dir: snapshot_dir)
      snap.save(server.instance_variable_get(:@driver).state_data)
      server.send(:call_tui_close)

      server.send(:call_tui_start, { "command" => "echo different" })
      result = server.send(:call_tui_assert_snapshot, { "name" => "mcp_assert_mismatch" })
      expect(result).to include("MISMATCH")
    ensure
      server.send(:call_tui_close)
    end
  end

  describe "#ensure_driver!" do
    it "raises Error when no driver is active" do
      expect { server.send(:ensure_driver!) }.to raise_error(TUITD::Error, /No TUI session/)
    end
  end
end
