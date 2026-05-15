# Simple smoke test for the MCP server.
# Simulates an MCP client session.
# Usage: ruby test/mcp_smoke_test.rb

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "tui_td"
require "json"

tests = 0
passed = 0

def assert(label, condition)
  if condition
    puts "  PASS: #{label}"
    true
  else
    puts "  FAIL: #{label}"
    false
  end
end

def simulate_server(input_lines)
  responses = []

  # Server using symbol keys internally; we simulate via handle_request
  # which also returns symbol-keyed hashes
  server = TUITD::MCP::Server.new(rows: 10, cols: 40)

  input_lines.each do |line|
    req = JSON.parse(line)  # string keys from JSON parse
    resp = server.send(:handle_request, req)
    json_str = JSON.generate(resp)
    responses << json_str if resp  # keep as JSON strings for consistent API
  end

  responses
end

puts "=== MCP Server Smoke Test ==="
puts

# Test 1: Initialize
puts "Test 1: Initialize"
init_req = %({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}})
responses = simulate_server([init_req])
r1 = JSON.parse(responses[0])
assert("returns result, not error", r1["result"] != nil)
assert("correct protocol version", r1.dig("result", "protocolVersion") == "2024-11-05")
assert("has tools capability", r1.dig("result", "capabilities", "tools") != nil)
passed += 3 if r1["result"] && r1.dig("result", "protocolVersion") == "2024-11-05"
tests += 3

# Test 2: tools/list
puts "\nTest 2: tools/list"
list_req = %({"jsonrpc":"2.0","id":2,"method":"tools/list"})
responses = simulate_server([list_req])
r2 = JSON.parse(responses[0])
tools = r2.dig("result", "tools") || []
tool_names = tools.map { |t| t["name"] }

assert("returns tool list", tools.length > 0)
assert("includes tui_start", tool_names.include?("tui_start"))
assert("includes tui_send", tool_names.include?("tui_send"))
assert("includes tui_state", tool_names.include?("tui_state"))
assert("includes tui_close", tool_names.include?("tui_close"))
assert("includes tui_screenshot", tool_names.include?("tui_screenshot"))
assert("includes tui_send_key", tool_names.include?("tui_send_key"))
assert("includes tui_wait_for_text", tool_names.include?("tui_wait_for_text"))
assert("includes tui_wait_for_stable", tool_names.include?("tui_wait_for_stable"))
assert("includes tui_plain_text", tool_names.include?("tui_plain_text"))
passed += 9 if tool_names.length >= 9
tests += 9

# Test 3: Unknown method
puts "\nTest 3: Unknown method"
unknown_req = %({"jsonrpc":"2.0","id":3,"method":"bogus"})
responses = simulate_server([unknown_req])
r3 = JSON.parse(responses[0])
assert("returns error for unknown method", r3["error"] != nil)
assert("error code -32601", r3.dig("error", "code") == -32601)
passed += 2
tests += 2

# Test 4: tui_start with echo (simple command)
puts "\nTest 4: tui_start actual command"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"echo hello"}}})
])
r4 = JSON.parse(responses[0], symbolize_names: true)
result_text = r4.dig(:result, :content, 0, :text) || ""

assert("starts with OK", result_text.start_with?("OK"))
assert("includes 'hello' in output", result_text.include?("hello"))
passed += 2
tests += 2

# Test 5: tui_state after start
puts "\nTest 5: tui_state"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"echo hello"}}}),
  %({"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"tui_state","arguments":{}}})
])
r7 = JSON.parse(responses[1], symbolize_names: true)
state_text = r7.dig(:result, :content, 0, :text) || ""

assert("state contains hello", state_text.include?("hello"))
assert("state contains cursor position", state_text.include?("cursor") && state_text.include?("row"))
passed += 2
tests += 2

# Test 6: tui_close
puts "\nTest 6: tui_close"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"echo hello"}}}),
  %({"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"tui_close","arguments":{}}})
])
r9 = JSON.parse(responses[1], symbolize_names: true)
close_text = r9.dig(:result, :content, 0, :text) || ""

assert("close returns OK", close_text.include?("OK"))
assert("close mentions session closed", close_text.include?("closed"))
passed += 2
tests += 2

# Summary
puts "\n=== Results: #{passed}/#{tests} passed ==="
if passed < tests
  puts "Some tests failed!"
  exit 1
else
  puts "All tests passed!"
end
