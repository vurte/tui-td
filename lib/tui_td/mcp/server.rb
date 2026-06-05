# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength

require "json"

module TUITD
  module MCP
    # Model Context Protocol server for tui-td.
    #
    # Implements JSON-RPC 2.0 over stdio transport.
    # Compatible with MCP specification (protocol version 2024-11-05).
    #
    # Usage:
    #   tui-td serve
    #
    # Exposes tools that any MCP client can call:
    #   tui_start, tui_send, tui_send_key, tui_wait_for_text,
    #   tui_state, tui_screenshot, tui_html_render, tui_plain_text, tui_close
    #
    class Server
      PROTOCOL_VERSION = "2024-11-05"
      SERVER_NAME = "tui-td"
      SERVER_VERSION = TUITD::VERSION

      def initialize(rows: 40, cols: 120, timeout: 30)
        @rows = rows
        @cols = cols
        @timeout = timeout
        @driver = nil
        @running = true
      end

      # Start the MCP server (reads from stdin, writes to stdout)
      def start
        $stdout.sync = true
        $stderr.sync = true

        # Signal readiness
        warn "[tui-td MCP] Server started, awaiting JSON-RPC on stdin..."

        while @running && (line = $stdin.gets)
          line = line.strip
          next if line.empty?

          begin
            request = JSON.parse(line)
            response = handle_request(request)

            puts JSON.generate(response) if response
            $stdout.flush
          rescue JSON::ParserError => e
            error_response(nil, -32_700, "Parse error: #{e.message}")
          rescue StandardError => e
            warn "[tui-td MCP] Error: #{e.class}: #{e.message}"
            warn e.backtrace.first(5).join("\n  ") if $DEBUG
          end
        end

        @driver&.close
      end

      ALLOWED_OUTPUT_DIRS = ["/tmp"].freeze

      private

      def handle_request(request)
        method = request["method"]
        id = request["id"]
        params = request["params"] || {}

        case method
        when "initialize"
          handle_initialize(params, id)
        when "notifications/initialized"
          nil # No response needed
        when "tools/list"
          handle_tools_list(id)
        when "tools/call"
          handle_tools_call(params, id)
        else
          if method&.start_with?("notifications/")
            nil # Ignore unknown notifications
          else
            error_response(id, -32_601, "Method not found: #{method}")
          end
        end
      end

      # Initialize handshake
      def handle_initialize(_params, id)
        {
          jsonrpc: "2.0",
          id: id,
          result: {
            protocolVersion: PROTOCOL_VERSION,
            capabilities: {
              tools: {},
            },
            serverInfo: {
              name: SERVER_NAME,
              version: SERVER_VERSION,
            },
          },
        }
      end

      # Return list of available tools
      def handle_tools_list(id)
        {
          jsonrpc: "2.0",
          id: id,
          result: {
            tools: [
              {
                name: "tui_start",
                description: "Start a TUI (Terminal User Interface) application in a PTY. Must be called first before any other tui_* tools.",
                inputSchema: {
                  type: "object",
                  properties: {
                    command: {
                      type: "string",
                      description: "The command to run (e.g., 'htop', 'vim file.txt')",
                    },
                    rows: {
                      type: "integer",
                      description: "Terminal height in rows (default: 40)",
                      default: 40,
                    },
                    cols: {
                      type: "integer",
                      description: "Terminal width in columns (default: 120)",
                      default: 120,
                    },
                    timeout: {
                      type: "integer",
                      description: "Timeout in seconds for waits (default: 30)",
                      default: 30,
                    },
                  },
                  required: ["command"],
                },
              },
              {
                name: "tui_send",
                description: "Send text input to the running TUI. Text is written as-is (use \\n for newline/enter, \\r just in case).",
                inputSchema: {
                  type: "object",
                  properties: {
                    text: {
                      type: "string",
                      description: "Text to send to the TUI. Use \\n for enter/newline.",
                    },
                  },
                  required: ["text"],
                },
              },
              {
                name: "tui_send_key",
                description: "Send a special key press (arrow keys, enter, tab, etc.) to the TUI.",
                inputSchema: {
                  type: "object",
                  properties: {
                    key: {
                      type: "string",
                      enum: %w[enter tab escape up down left right
                               backspace ctrl_c ctrl_d ctrl_z page_up page_down
                               home end delete],
                      description: "Key to press",
                    },
                  },
                  required: ["key"],
                },
              },
              {
                name: "tui_wait_for_text",
                description: "Wait until the terminal output contains the specified text (with timeout).",
                inputSchema: {
                  type: "object",
                  properties: {
                    text: {
                      type: "string",
                      description: "Text to wait for in the terminal output",
                    },
                    timeout: {
                      type: "integer",
                      description: "Custom timeout in seconds (overrides default)",
                      default: 30,
                    },
                  },
                  required: ["text"],
                },
              },
              {
                name: "tui_wait_for_stable",
                description: "Wait until the terminal output stabilizes (no new data for 300ms). Useful after sending commands.",
                inputSchema: {
                  type: "object",
                  properties: {
                    timeout: {
                      type: "integer",
                      description: "Custom timeout in seconds",
                      default: 30,
                    },
                  },
                },
              },
              {
                name: "tui_state",
                description: "Get the current state of the terminal: cursor position, plain text, visual highlights (bold/colored text), and grid size.",
                inputSchema: {
                  type: "object",
                  properties: {
                    format: {
                      type: "string",
                      enum: %w[ai full text],
                      description: "Output format: 'ai' (compact, text+highlights, default), 'full' (complete cell grid with ANSI colors), 'text' (plain text only)",
                      default: "ai",
                    },
                  },
                },
              },
              {
                name: "tui_plain_text",
                description: "Get the current terminal content as plain text (all ANSI stripped).",
                inputSchema: {
                  type: "object",
                  properties: {},
                },
              },
              {
                name: "tui_screenshot",
                description: "Capture a PNG screenshot of the current terminal state. Renders the terminal grid directly using an embedded monochrome font.",
                inputSchema: {
                  type: "object",
                  properties: {
                    path: {
                      type: "string",
                      description: "Output file path (optional, auto-generated if omitted)",
                    },
                  },
                },
              },
              {
                name: "tui_html_render",
                description: "Render the current terminal state as a self-contained HTML document. Returns faithful browser visualization with colors, bold/italic/underline, cursor indicator. Use this to SEE exactly what the TUI displays.",
                inputSchema: {
                  type: "object",
                  properties: {
                    path: {
                      type: "string",
                      description: "Optional file path to save the HTML. If omitted, the HTML content is returned inline so you can view it directly.",
                    },
                  },
                },
              },
              {
                name: "tui_wait_for_exit",
                description: "Wait until the TUI process exits. Returns the exit status code (0 = success, non-zero = error).",
                inputSchema: {
                  type: "object",
                  properties: {},
                },
              },
              {
                name: "tui_exit_status",
                description: "Get the exit status of the TUI process. Returns nil if still running, otherwise the exit code.",
                inputSchema: {
                  type: "object",
                  properties: {},
                },
              },
              {
                name: "tui_find_text",
                description: "Search for text or regex pattern in the current terminal state. Returns positions of all matches with surrounding context. Supports match modes: partial (default, substring), exact (whole row), regex (Ruby regex).",
                inputSchema: {
                  type: "object",
                  properties: {
                    pattern: {
                      type: "string",
                      description: "Text or regex pattern to search for (e.g., 'error', 'ERROR|FAIL')",
                    },
                    match: {
                      type: "string",
                      enum: %w[partial exact regex],
                      description: "Match mode: partial (substring), exact (whole row match), regex (Ruby regex). Default: partial.",
                    },
                  },
                  required: ["pattern"],
                },
              },
              {
                name: "tui_find_elements",
                description: "Search for UI elements in the terminal state. Returns buttons, checkboxes, dialogs, statusbars, progress bars, inputs, labels, menus, and tabs detected by heuristic analysis. Optionally filter by role, text, checked, and/or disabled state.",
                inputSchema: {
                  type: "object",
                  properties: {
                    role: {
                      type: "string",
                      description: "Filter by role: button, checkbox, dialog, statusbar, progress, input, label, menu, tab. Omit to return all.",
                    },
                    text: {
                      type: "string",
                      description: "Filter by visible text (partial match). Optional.",
                    },
                    checked: {
                      type: "boolean",
                      description: "Filter by checked state (checkboxes). Optional.",
                    },
                    disabled: {
                      type: "boolean",
                      description: "Filter by disabled state. Optional.",
                    },
                  },
                },
              },
              {
                name: "tui_element_actions",
                description: "Get action hashes for a detected UI element. Returns click/type/press_key actions that can be used to interact with the element via tui_send/tui_send_key.",
                inputSchema: {
                  type: "object",
                  properties: {
                    role: {
                      type: "string",
                      description: "Element role: button, checkbox, dialog, statusbar, progress, input, label, menu, tab",
                    },
                    text: {
                      type: "string",
                      description: "Filter by visible text (partial match). Optional.",
                    },
                  },
                  required: ["role"],
                },
              },
              {
                name: "tui_diff",
                description: "Compare the current terminal state against a previous state. Returns cell-level differences. Use chars_only: true to ignore color/style changes.",
                inputSchema: {
                  type: "object",
                  properties: {
                    snapshot: {
                      type: "object",
                      description: "A previously saved state snapshot (from tui_state or a prior capture). Must include size, cursor, and rows keys.",
                    },
                    chars_only: {
                      type: "boolean",
                      description: "If true, only compare character differences (ignore color/style). Default: false.",
                    },
                  },
                  required: ["snapshot"],
                },
              },
              {
                name: "tui_annotate_element",
                description: "Manually register a UI element at a specific region. The annotation is picked up by tui_find_elements for subsequent queries.",
                inputSchema: {
                  type: "object",
                  properties: {
                    role: {
                      type: "string",
                      description: "Element role (e.g., button, dialog, statusbar, progress, input, label, menu, tab).",
                    },
                    row: {
                      type: "integer",
                      description: "Top row of the element.",
                    },
                    col: {
                      type: "integer",
                      description: "Left column of the element.",
                    },
                    width: {
                      type: "integer",
                      description: "Width in columns (default: 1).",
                      default: 1,
                    },
                    height: {
                      type: "integer",
                      description: "Height in rows (default: 1).",
                      default: 1,
                    },
                    text: {
                      type: "string",
                      description: "Visible text label for the element.",
                    },
                  },
                  required: %w[role row col],
                },
              },
              {
                name: "tui_save_snapshot",
                description: "Save the current terminal state as a named snapshot to disk. Used to create golden masters for snapshot testing.",
                inputSchema: {
                  type: "object",
                  properties: {
                    name: {
                      type: "string",
                      description: "Snapshot name (e.g., 'login_screen'). Saved as <name>.json in the snapshot directory.",
                    },
                    type: {
                      type: "string",
                      enum: %w[text full png html all],
                      description: "Snapshot type. text=chars_only (default), full=chars+colors, png=screenshot, html=render, all=all formats.",
                    },
                  },
                  required: ["name"],
                },
              },
              {
                name: "tui_assert_snapshot",
                description: "Assert the current terminal state matches a named snapshot on disk. On first run, creates the snapshot automatically. Set UPDATE_SNAPSHOTS=1 to force update all snapshots.",
                inputSchema: {
                  type: "object",
                  properties: {
                    name: {
                      type: "string",
                      description: "Snapshot name to compare against.",
                    },
                    type: {
                      type: "string",
                      enum: %w[text full png html all],
                      description: "Snapshot type. Default: text.",
                    },
                  },
                  required: ["name"],
                },
              },
              {
                name: "tui_close",
                description: "Close the TUI application and clean up the PTY session. Call this when finished.",
                inputSchema: {
                  type: "object",
                  properties: {},
                },
              },
            ],
          },
        }
      end

      # Call a tool
      def handle_tools_call(params, id)
        tool_name = params["name"]
        args = params["arguments"] || {}

        result = case tool_name
                 when "tui_start"     then call_tui_start(args)
                 when "tui_send"      then call_tui_send(args)
                 when "tui_send_key"  then call_tui_send_key(args)
                 when "tui_wait_for_text" then call_tui_wait_for_text(args)
                 when "tui_wait_for_stable" then call_tui_wait_for_stable(args)
                 when "tui_state" then call_tui_state(args)
                 when "tui_plain_text" then call_tui_plain_text
                 when "tui_screenshot" then call_tui_screenshot(args)
                 when "tui_html_render" then call_tui_html_render(args)
                 when "tui_wait_for_exit" then call_tui_wait_for_exit
                 when "tui_exit_status" then call_tui_exit_status
                 when "tui_find_text" then call_tui_find_text(args)
                 when "tui_find_elements" then call_tui_find_elements(args)
                 when "tui_element_actions" then call_tui_element_actions(args)
                 when "tui_diff" then call_tui_diff(args)
                 when "tui_annotate_element" then call_tui_annotate_element(args)
                 when "tui_save_snapshot" then call_tui_save_snapshot(args)
                 when "tui_assert_snapshot" then call_tui_assert_snapshot(args)
                 when "tui_close" then call_tui_close
                 else
                   return error_response(id, -32_602, "Unknown tool: #{tool_name}")
                 end

        {
          jsonrpc: "2.0",
          id: id,
          result: {
            content: [
              {
                type: "text",
                text: result,
              },
            ],
          },
        }
      rescue TUITD::TimeoutError => e
        {
          jsonrpc: "2.0",
          id: id,
          result: {
            content: [
              {
                type: "text",
                text: "TIMEOUT: #{e.message}",
              },
            ],
            isError: false,
          },
        }
      rescue StandardError => e
        {
          jsonrpc: "2.0",
          id: id,
          result: {
            content: [
              {
                type: "text",
                text: "ERROR: #{e.class}: #{e.message}",
              },
            ],
            isError: true,
          },
        }
      end

      # --- Tool implementations ---

      def call_tui_start(args)
        command = args["command"] or return "ERROR: 'command' argument is required"
        rows = args["rows"] || @rows
        cols = args["cols"] || @cols
        timeout = args["timeout"] || @timeout

        @driver&.close
        @driver = Driver.new(command, rows: rows, cols: cols, timeout: timeout)
        @driver.start

        state_data = @driver.state_data
        text = state_to_ai_text(state_data)

        "OK: Started '#{command}' (#{cols}x#{rows})\n#{text}"
      end

      def call_tui_send(args)
        ensure_driver!
        text = args["text"] or return "ERROR: 'text' argument is required"
        @driver.send(text)
        "OK: Sent #{text.length} characters"
      end

      def call_tui_send_key(args)
        ensure_driver!
        key = args["key"] or return "ERROR: 'key' argument is required"
        key_sym = key.to_sym
        @driver.send_keys(key_sym)
        "OK: Sent key '#{key}'"
      end

      def call_tui_wait_for_text(args)
        ensure_driver!
        text = args["text"] or return "ERROR: 'text' argument is required"
        @driver.wait_for_text(text)

        state_data = @driver.state_data
        state_to_ai_text(state_data)
      end

      def call_tui_wait_for_stable(_args)
        ensure_driver!
        @driver.wait_for_stable

        state_data = @driver.state_data
        state_to_ai_text(state_data)
      end

      def call_tui_state(args)
        ensure_driver!
        state = TUITD::State.new(@driver.state_data)
        format = args["format"] || "ai"

        case format
        when "full"
          JSON.pretty_generate(@driver.state_data)
        when "text"
          state.plain_text
        else
          JSON.pretty_generate(state.to_ai_json)
        end
      end

      def call_tui_plain_text
        ensure_driver!
        state = TUITD::State.new(@driver.state_data)
        state.plain_text
      end

      def call_tui_screenshot(args)
        ensure_driver!
        path = safe_path(args["path"], ext: "png")
        result = @driver.screenshot(path)
        "OK: Screenshot saved to #{result}"
      end

      def call_tui_html_render(args)
        ensure_driver!
        path = args["path"]
        renderer = HtmlRenderer.new(@driver.state_data)

        if path
          safe = safe_path(path, ext: "html")
          renderer.render(safe)
          "OK: HTML saved to #{safe}"
        else
          renderer.to_html
        end
      end

      def call_tui_wait_for_exit
        ensure_driver!
        @driver.wait_for_exit
        status = @driver.exitstatus
        "OK: Process exited with status #{status}"
      end

      def call_tui_exit_status
        ensure_driver!
        status = @driver.exitstatus
        if status.nil?
          "Process is still running"
        else
          "Exit status: #{status}"
        end
      end

      def call_tui_find_text(args)
        ensure_driver!
        pattern = args["pattern"] or return "ERROR: 'pattern' argument is required"
        match_mode = (args["match"] || "partial").to_sym
        state = TUITD::State.new(@driver.state_data)
        matches = state.find_text(pattern, match: match_mode)

        if matches.empty?
          "No matches found for: #{pattern}"
        else
          lines = ["Found #{matches.size} match(es) for: #{pattern}"]
          matches.each do |m|
            lines << "  row #{m[:row]}, col #{m[:col]}: #{m[:full_line].strip}"
          end
          lines.join("\n")
        end
      end

      def call_tui_find_elements(args)
        ensure_driver!
        state = TUITD::State.new(@driver.state_data)
        selector = TUITD::Selector.new(state)

        role = args["role"]&.to_sym
        text = args["text"]
        checked = args.key?("checked") ? args["checked"] : nil
        disabled = args.key?("disabled") ? args["disabled"] : nil

        filters = {}
        filters[:text] = text if text
        filters[:checked] = checked unless checked.nil?
        filters[:disabled] = disabled unless disabled.nil?

        elements = if role
                     selector.get_by_role(role, **filters)
                   else
                     result = selector.elements
                     result = result.select { |e| e.text&.include?(text) } if text
                     result = result.select { |e| e.checked == checked } unless checked.nil?
                     result = result.select { |e| e.disabled == disabled } unless disabled.nil?
                     result
                   end

        if elements.empty?
          desc = role ? "role :#{role}" : "any role"
          desc += " with text #{text.inspect}" if text
          desc += " checked=#{checked}" unless checked.nil?
          desc += " disabled=#{disabled}" unless disabled.nil?
          "No elements found for #{desc}"
        else
          lines = ["Found #{elements.size} element(s):"]
          elements.each do |el|
            parts = ["  :#{el.role}"]
            parts << el.text.inspect if el.text
            parts << "at [#{el.row},#{el.col}]"
            parts << "#{el.width}x#{el.height}"
            parts << "(checked)" if el.checked
            parts << "(disabled)" if el.disabled
            parts << "(focused)" if el.focused
            lines << parts.join(" ")
          end
          lines.join("\n")
        end
      end

      def call_tui_element_actions(args)
        ensure_driver!
        role = args["role"]&.to_sym || (return "ERROR: 'role' argument is required")
        text = args["text"]

        state = TUITD::State.new(@driver.state_data)
        selector = TUITD::Selector.new(state)

        filters = {}
        filters[:text] = text if text
        element = selector.get_by_role(role, **filters).first

        unless element
          desc = "No #{role} element"
          desc << " with text #{text.inspect}" if text
          desc << " found"
          return desc
        end

        lines = ["Element: :#{element.role} #{element.text.inspect} at [#{element.row},#{element.col}]"]
        lines << "Bounds: #{element.bounds.inspect}"
        lines << "Actions:"
        lines << "  click:       #{element.click.inspect}"
        lines << "  type(text):  #{element.type("text").inspect}"
        lines << "  press_key:   #{element.press_key(:enter).inspect}"
        lines.join("\n")
      end

      def call_tui_diff(args)
        ensure_driver!
        snapshot = args["snapshot"] or return "ERROR: 'snapshot' argument is required"
        chars_only = args["chars_only"] || false

        current = TUITD::State.new(@driver.state_data)
        snapshot = deep_symbolize(snapshot) if snapshot.is_a?(Hash)
        diffs = current.diff(snapshot, chars_only: chars_only)

        if diffs.empty?
          "No differences found (chars_only: #{chars_only})"
        else
          lines = ["Found #{diffs.size} difference(s):"]
          diffs.first(20).each do |d|
            before_char = d[:before][:char].inspect
            after_char = d[:after][:char].inspect
            lines << "  [#{d[:row]},#{d[:col]}] #{before_char} -> #{after_char}"
          end
          lines << "  ... (truncated)" if diffs.size > 20
          lines.join("\n")
        end
      end

      def call_tui_annotate_element(args)
        ensure_driver!
        role = args["role"] or return "ERROR: 'role' argument is required"
        row = args["row"] or return "ERROR: 'row' argument is required"
        col = args["col"] or return "ERROR: 'col' argument is required"
        width = args["width"] || 1
        height = args["height"] || 1
        text = args["text"]

        state = TUITD::State.new(@driver.state_data)
        state.annotate_role(role, row: row, col: col, width: width, height: height, text: text)

        desc = "OK: Annotated :#{role} at [#{row},#{col}] #{width}x#{height}"
        desc << " with text #{text.inspect}" if text
        desc
      end

      def call_tui_save_snapshot(args)
        ensure_driver!
        name = args["name"] or return "ERROR: 'name' argument is required"
        type = (args["type"] || "text").to_sym
        snap = Snapshot.new(name, type: type)
        snap.save(@driver.state_data)
        "OK: Snapshot '#{name}' (type: #{type}) saved to #{snap.path}"
      end

      def call_tui_assert_snapshot(args)
        ensure_driver!
        name = args["name"] or return "ERROR: 'name' argument is required"
        type = (args["type"] || "text").to_sym
        snap = Snapshot.new(name, type: type)

        if TUITD.configuration.update_snapshots?
          snap.save(@driver.state_data)
          return "OK: Snapshot '#{name}' (type: #{type}) updated (UPDATE_SNAPSHOTS mode)"
        end

        unless snap.exists?
          snap.save(@driver.state_data)
          return "OK: Snapshot '#{name}' (type: #{type}) created (first run)"
        end

        result = snap.compare(@driver.state_data)
        if result.passed?
          "OK: Snapshot '#{name}' (type: #{type}) matches"
        else
          "MISMATCH: #{result.message}"
        end
      end

      def call_tui_close
        @driver&.close
        @driver = nil
        "OK: TUI session closed"
      end

      # --- Helpers ---

      def deep_symbolize(obj)
        case obj
        when Hash
          obj.each_with_object({}) { |(k, v), h| h[k.to_sym] = deep_symbolize(v) }
        when Array
          obj.map { |v| deep_symbolize(v) }
        else
          obj
        end
      end

      def safe_path(user_path, ext:)
        default = File.join("/tmp", "tui_td_#{Time.now.to_i}.#{ext}")
        resolved = File.expand_path(user_path || default)

        unless ALLOWED_OUTPUT_DIRS.any? { |dir| resolved.start_with?(File.expand_path(dir)) }
          raise TUITD::Error, "Output path must be under one of: #{ALLOWED_OUTPUT_DIRS.join(", ")}"
        end

        resolved
      end

      def ensure_driver!
        raise Error, "No TUI session active. Call tui_start first." if @driver.nil?
      end

      def state_to_ai_text(state_data)
        state = TUITD::State.new(state_data)
        json = state.to_ai_json

        lines = []
        lines << "Terminal: #{json[:size][:cols]}x#{json[:size][:rows]}"
        lines << "Cursor:   [#{json[:cursor][:row]}, #{json[:cursor][:col]}]"

        if json[:highlights]&.any?
          lines << "Highlights (bold/colored text):"
          json[:highlights].each { |h| lines << "  row #{h[:row]}: #{h[:text]}" }
        end

        lines << "--- Full text ---"
        text_lines = json[:text].split("\n")
        text_lines.each { |l| lines << l }

        lines.join("\n")
      end

      def error_response(id, code, message)
        {
          jsonrpc: "2.0",
          id: id,
          error: {
            code: code,
            message: message,
          },
        }
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength
