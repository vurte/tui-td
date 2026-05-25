# Smoke test for the MCP server.
# Simulates an MCP client session.
# Usage: ruby test/mcp_smoke_test.rb

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "tui_td"
require "json"
require "tempfile"

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

def simulate_server(input_lines, rows: 10, cols: 40)
  responses = []

  server = TUITD::MCP::Server.new(rows: rows, cols: cols)

  input_lines.each do |line|
    req = JSON.parse(line)
    resp = server.send(:handle_request, req)
    json_str = JSON.generate(resp)
    responses << json_str if resp
  end

  responses
end

def start_and_get_response(method_name, args = {})
  req = %({"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"#{method_name}","arguments":#{JSON.generate(args)}}})
  simulate_server([req]).first
end

puts "=== MCP Server Smoke Test ==="
puts

# -- Test 1: Initialize --------------------------------------------
puts "Test 1: Initialize"
init_req = %({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}})
responses = simulate_server([init_req])
r1 = JSON.parse(responses[0])
tc = 0
tc += 1 if assert("returns result, not error", r1["result"] != nil)
tc += 1 if assert("correct protocol version", r1.dig("result", "protocolVersion") == "2024-11-05")
tc += 1 if assert("has tools capability", r1.dig("result", "capabilities", "tools") != nil)
passed += tc
tests += 3

# -- Test 2: tools/list --------------------------------------------
puts "\nTest 2: tools/list"
list_req = %({"jsonrpc":"2.0","id":2,"method":"tools/list"})
responses = simulate_server([list_req])
r2 = JSON.parse(responses[0])
tools = r2.dig("result", "tools") || []
tool_names = tools.map { |t| t["name"] }

expected_tools = %w[tui_start tui_send tui_state tui_close tui_screenshot
                    tui_send_key tui_wait_for_text tui_wait_for_stable
                    tui_plain_text tui_html_render tui_wait_for_exit
                    tui_exit_status tui_find_text]
tc = 0
tc += 1 if assert("returns tool list", tools.length > 0)
expected_tools.each do |tname|
  tc += 1 if assert("includes #{tname}", tool_names.include?(tname))
end
passed += tc
tests += expected_tools.length + 1

# -- Test 3: Unknown method ----------------------------------------
puts "\nTest 3: Unknown method"
unknown_req = %({"jsonrpc":"2.0","id":3,"method":"bogus"})
responses = simulate_server([unknown_req])
r3 = JSON.parse(responses[0])
tc = 0
tc += 1 if assert("returns error for unknown method", r3["error"] != nil)
tc += 1 if assert("error code -32601", r3.dig("error", "code") == -32601)
passed += tc
tests += 2

# -- Test 4: tui_start ---------------------------------------------
puts "\nTest 4: tui_start actual command"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"echo hello"}}})
])
r4 = JSON.parse(responses[0], symbolize_names: true)
result_text = r4.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("starts with OK", result_text.start_with?("OK"))
tc += 1 if assert("includes 'hello' in output", result_text.include?("hello"))
passed += tc
tests += 2

# -- Test 5: tui_state ---------------------------------------------
puts "\nTest 5: tui_state"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"echo hello"}}}),
  %({"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"tui_state","arguments":{}}})
])
r5 = JSON.parse(responses[1], symbolize_names: true)
state_text = r5.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("state contains hello", state_text.include?("hello"))
tc += 1 if assert("state contains cursor position", state_text.include?("cursor") && state_text.include?("row"))
passed += tc
tests += 2

# -- Test 6: tui_close ---------------------------------------------
puts "\nTest 6: tui_close"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"echo hello"}}}),
  %({"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"tui_close","arguments":{}}})
])
r6 = JSON.parse(responses[1], symbolize_names: true)
close_text = r6.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("close returns OK", close_text.include?("OK"))
tc += 1 if assert("close mentions session closed", close_text.include?("closed"))
passed += tc
tests += 2

# -- Test 7: tui_send ----------------------------------------------
puts "\nTest 7: tui_send"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"cat"}}}),
  %({"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"tui_send","arguments":{"text":"hello world"}}})
])
r7 = JSON.parse(responses[1], symbolize_names: true)
send_text = r7.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("tui_send returns OK", send_text.start_with?("OK"))
tc += 1 if assert("reports character count", send_text.include?("11 characters"))
passed += tc
tests += 2

# -- Test 8: tui_send_key ------------------------------------------
puts "\nTest 8: tui_send_key"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"cat"}}}),
  %({"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"tui_send_key","arguments":{"key":"enter"}}})
])
r8 = JSON.parse(responses[1], symbolize_names: true)
key_text = r8.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("tui_send_key returns OK", key_text.start_with?("OK"))
tc += 1 if assert("mentions the key name", key_text.include?("enter"))
passed += tc
tests += 2

# -- Test 9: tui_wait_for_text -------------------------------------
puts "\nTest 9: tui_wait_for_text"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"echo hello"}}}),
  %({"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"tui_wait_for_text","arguments":{"text":"hello"}}})
])
r9 = JSON.parse(responses[1], symbolize_names: true)
wait_text = r9.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("tui_wait_for_text contains hello", wait_text.include?("hello"))
tc += 1 if assert("no timeout error", !wait_text.start_with?("TIMEOUT") && !wait_text.start_with?("ERROR"))
passed += tc
tests += 2

# -- Test 10: tui_wait_for_stable ----------------------------------
puts "\nTest 10: tui_wait_for_stable"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":15,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"echo hello"}}}),
  %({"jsonrpc":"2.0","id":16,"method":"tools/call","params":{"name":"tui_wait_for_stable","arguments":{}}})
])
r10 = JSON.parse(responses[1], symbolize_names: true)
stable_text = r10.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("tui_wait_for_stable returns output", stable_text.length > 0)
tc += 1 if assert("contains hello after stable", stable_text.include?("hello"))
tc += 1 if assert("no error after stable", !stable_text.start_with?("TIMEOUT") && !stable_text.start_with?("ERROR"))
passed += tc
tests += 3

# -- Test 11: tui_plain_text ---------------------------------------
puts "\nTest 11: tui_plain_text"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":17,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"echo hello"}}}),
  %({"jsonrpc":"2.0","id":18,"method":"tools/call","params":{"name":"tui_plain_text","arguments":{}}})
])
r11 = JSON.parse(responses[1], symbolize_names: true)
plain_text = r11.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("plain_text contains hello", plain_text.include?("hello"))
tc += 1 if assert("plain_text no ANSI escape codes", !plain_text.include?("\e["))
passed += tc
tests += 2

# -- Test 12: tui_screenshot ---------------------------------------
puts "\nTest 12: tui_screenshot"
tmpfile = "/tmp/tui_td_smoke_test_#{Process.pid}.png"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":19,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"echo hello"}}}),
  %({"jsonrpc":"2.0","id":20,"method":"tools/call","params":{"name":"tui_screenshot","arguments":{"path":"#{tmpfile}"}}})
])
r12 = JSON.parse(responses[1], symbolize_names: true)
shot_text = r12.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("screenshot returns OK", shot_text.start_with?("OK"))
tc += 1 if assert("screenshot file exists", File.exist?(tmpfile))
tc += 1 if assert("screenshot file non-empty", File.size(tmpfile) > 0)
File.delete(tmpfile) if File.exist?(tmpfile)
passed += tc
tests += 3

# -- Test 13: tui_html_render inline -------------------------------
puts "\nTest 13: tui_html_render (inline)"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":21,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"echo hello"}}}),
  %({"jsonrpc":"2.0","id":22,"method":"tools/call","params":{"name":"tui_html_render","arguments":{}}})
])
r13 = JSON.parse(responses[1], symbolize_names: true)
html_text = r13.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("HTML contains <html> tag", html_text.include?("<html"))
tc += 1 if assert("HTML contains rendered text", html_text.include?("hello"))
tc += 1 if assert("HTML is self-contained", html_text.include?("</html>"))
passed += tc
tests += 3

# -- Test 14: tui_html_render to file ------------------------------
puts "\nTest 14: tui_html_render (to file)"
tmphtml = "/tmp/tui_td_smoke_html_#{Process.pid}.html"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":23,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"echo hello"}}}),
  %({"jsonrpc":"2.0","id":24,"method":"tools/call","params":{"name":"tui_html_render","arguments":{"path":"#{tmphtml}"}}})
])
r14 = JSON.parse(responses[1], symbolize_names: true)
html_file_text = r14.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("HTML file returns OK", html_file_text.start_with?("OK"))
tc += 1 if assert("HTML file exists", File.exist?(tmphtml))
tc += 1 if assert("HTML file contains <html>", File.read(tmphtml).include?("<html"))
File.delete(tmphtml) if File.exist?(tmphtml)
passed += tc
tests += 3

# -- Test 15: tui_state with format "text" -------------------------
puts "\nTest 15: tui_state format=text"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":25,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"echo hello"}}}),
  %({"jsonrpc":"2.0","id":26,"method":"tools/call","params":{"name":"tui_state","arguments":{"format":"text"}}})
])
r15 = JSON.parse(responses[1], symbolize_names: true)
text_format = r15.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("text format contains hello", text_format.include?("hello"))
tc += 1 if assert("text format is not JSON", !text_format.start_with?("{"))
passed += tc
tests += 2

# -- Test 16: tui_state with format "full" -------------------------
puts "\nTest 16: tui_state format=full"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":27,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"echo hello"}}}),
  %({"jsonrpc":"2.0","id":28,"method":"tools/call","params":{"name":"tui_state","arguments":{"format":"full"}}})
])
r16 = JSON.parse(responses[1], symbolize_names: true)
full_text = r16.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("full format is JSON", full_text.start_with?("{"))
tc += 1 if assert("full format contains rows data", full_text.include?("rows") && full_text.include?("cursor"))
passed += tc
tests += 2

# =================================================================
# Error paths
# =================================================================

# -- Test 17: Unknown tool -----------------------------------------
puts "\nTest 17: Unknown tool (error -32602)"
req = %({"jsonrpc":"2.0","id":29,"method":"tools/call","params":{"name":"bogus_tool","arguments":{}}})
responses = simulate_server([req])
r17 = JSON.parse(responses[0], symbolize_names: true)
tc = 0
tc += 1 if assert("unknown tool returns error", r17[:error] != nil)
tc += 1 if assert("error code -32602", r17.dig(:error, :code) == -32602)
passed += tc
tests += 2

# -- Test 18: Tool call without tui_start --------------------------
puts "\nTest 18: Tool without active session"
req = %({"jsonrpc":"2.0","id":30,"method":"tools/call","params":{"name":"tui_state","arguments":{}}})
responses = simulate_server([req])
r18 = JSON.parse(responses[0], symbolize_names: true)
err_text = r18.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("returns ERROR for missing session", err_text.start_with?("ERROR"))
tc += 1 if assert("mentions tui_start", err_text.include?("tui_start") || err_text.include?("session") || err_text.include?("No TUI"))
passed += tc
tests += 2

# -- Test 19: Missing required argument ----------------------------
puts "\nTest 19: Missing required argument"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":31,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"cat"}}}),
  %({"jsonrpc":"2.0","id":32,"method":"tools/call","params":{"name":"tui_send","arguments":{}}})
])
r19 = JSON.parse(responses[1], symbolize_names: true)
missing_text = r19.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("returns ERROR for missing argument", missing_text.start_with?("ERROR"))
tc += 1 if assert("mentions 'text' argument", missing_text.include?("text"))
passed += tc
tests += 2

# -- Test 20: notifications/initialized returns nil ----------------
puts "\nTest 20: notifications/initialized"
req = %({"jsonrpc":"2.0","method":"notifications/initialized"})
responses = simulate_server([req])
tc = 0
tc += 1 if assert("notifications/initialized returns no response", responses.empty?)
passed += tc
tests += 1

# -- Test 21: Unknown notification returns nil ---------------------
puts "\nTest 21: Unknown notification"
req = %({"jsonrpc":"2.0","method":"notifications/cancelled"})
responses = simulate_server([req])
tc = 0
tc += 1 if assert("unknown notification returns no response", responses.empty?)
passed += tc
tests += 1

# =================================================================
# New tools: tui_wait_for_exit, tui_exit_status, tui_find_text
# =================================================================

# -- Test 22: tui_wait_for_exit ------------------------------------
puts "\nTest 22: tui_wait_for_exit"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":35,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"echo done"}}}),
  %({"jsonrpc":"2.0","id":36,"method":"tools/call","params":{"name":"tui_wait_for_exit","arguments":{}}})
])
r22 = JSON.parse(responses[1], symbolize_names: true)
exit_text = r22.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("wait_for_exit returns OK", exit_text.start_with?("OK"))
tc += 1 if assert("mentions exit status", exit_text.include?("status"))
passed += tc
tests += 2

# -- Test 23: tui_exit_status while running ------------------------
puts "\nTest 23: tui_exit_status (running)"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":37,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"sleep 5"}}}),
  %({"jsonrpc":"2.0","id":38,"method":"tools/call","params":{"name":"tui_exit_status","arguments":{}}})
])
r23 = JSON.parse(responses[1], symbolize_names: true)
running_text = r23.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("exit_status shows running or status", running_text.include?("running") || running_text.include?("status"))
passed += tc
tests += 1

# -- Test 24: tui_find_text ----------------------------------------
puts "\nTest 24: tui_find_text"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":39,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"echo hello world"}}}),
  %({"jsonrpc":"2.0","id":40,"method":"tools/call","params":{"name":"tui_find_text","arguments":{"pattern":"hello"}}})
])
r24 = JSON.parse(responses[1], symbolize_names: true)
find_text = r24.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("find_text finds hello", find_text.include?("hello"))
tc += 1 if assert("find_text reports match count", find_text.include?("match"))
passed += tc
tests += 2

# -- Test 25: tui_find_text no match -------------------------------
puts "\nTest 25: tui_find_text (no match)"
responses = simulate_server([
  %({"jsonrpc":"2.0","id":41,"method":"tools/call","params":{"name":"tui_start","arguments":{"command":"echo hello"}}}),
  %({"jsonrpc":"2.0","id":42,"method":"tools/call","params":{"name":"tui_find_text","arguments":{"pattern":"nonexistent"}}})
])
r25 = JSON.parse(responses[1], symbolize_names: true)
no_match = r25.dig(:result, :content, 0, :text) || ""
tc = 0
tc += 1 if assert("find_text says no matches", no_match.include?("No match"))
passed += tc
tests += 1

# =================================================================
# Summary
# =================================================================
puts "\n=== Results: #{passed}/#{tests} passed ==="
if passed < tests
  puts "Some tests failed!"
  exit 1
else
  puts "All tests passed!"
end
