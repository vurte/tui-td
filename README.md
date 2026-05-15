# TUI Test Drive

Testing framework for Terminal User Interfaces (TUIs) with MCP support.

A Ruby library, but language-agnostic through its JSON test format and MCP server — use it from any language on Linux and macOS.

**tui-td** lets you:
1. Start a TUI application in a virtual terminal (PTY)
2. See the output — as structured JSON, plain text, PNG screenshots, or HTML renders
3. Send input — keystrokes, text, control sequences
4. Analyze output — find text, check colors, detect cursor position
5. Loop — adjust and retest without manual intervention
6. Integrate — works with any language via JSON test files or MCP

## Installation

### 1. Install Ruby

**rbenv (recommended):**

```bash
# macOS
brew install rbenv ruby-build
echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc

# Linux
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'eval "$(~/.rbenv/bin/rbenv init - bash)"' >> ~/.bashrc
```

Then install Ruby 3 and activate it:

```bash
rbenv install 3.4.1
rbenv global 3.4.1
ruby --version  # must show 3.0+
```

**Alternative — Homebrew (macOS):**

```bash
brew install ruby
```

### 2. Install tui-td

```bash
gem install tui-td
```

### 3. Test

```bash
tui-td capture "echo Hello World"
```

## CLI Usage

```bash
# Capture output of any terminal command
tui-td capture "ls -la"

# Capture with custom terminal size
tui-td -r 24 -c 80 capture "vim --version"

# Run a command from a specific directory
tui-td -C /path/to/project capture "make test"

# Output as JSON for scripts
tui-td --json capture "ls -la"

# Save as HTML for browser visualization
tui-td --html output.html capture "htop"

# Save as a PNG screenshot
tui-td --screenshot output.png capture "htop"

# Drive a TUI interactively
tui-td drive "htop"
# At the > prompt:
#   state       Show current terminal state as pretty JSON
#   raw         Show raw ANSI output (first 2000 chars)
#   key <name>  Send a special key (enter, up, down, tab, escape, ctrl_c, ...)
#   exit        Quit
#   <anything>  Sent as text + Enter to the TUI

# Start MCP server for AI integration
tui-td serve
```

## CLI Reference

```
Usage: tui-td <command> [options]

Commands:
  serve              Start MCP server (JSON-RPC over stdio)
  test <file>        Run JSON test file
  run <command>      Run a TUI app and show live output
  drive <command>    Drive a TUI with structured state output
  capture <command>  Run once, capture and display state

Global options:
  -r, --rows N          Terminal rows (default: 40)
  -c, --cols N          Terminal cols (default: 120)
  -C, --chdir PATH      Working directory for the command
  -t, --timeout N       Timeout in seconds (default: 30)
  --screenshot PATH     Save PNG screenshot
  --html PATH           Save HTML render for browser viewing
  --json                Output state as compact JSON (includes raw ANSI)
  --pretty              Output state as pretty JSON
  --text                Output state as plain text table (default)
  -h, --help            Show help
```

## Ruby API

### Driver — Start, send, capture

```ruby
require "tui_td"

driver = TUITD::Driver.new("htop", rows: 40, cols: 120, timeout: 30)
driver.start

# Send input
driver.send("hello world\n")
driver.send_keys(:enter)     # :enter, :tab, :escape
driver.send_keys(:up)        # :up, :down, :left, :right
driver.send_keys(:ctrl_c)    # :ctrl_c, :ctrl_d, :backspace

# Wait for expected output
driver.wait_for_text("> ")
driver.wait_for_stable          # Wait until 300ms of silence
driver.wait_for_exit            # Wait until process ends

# Read output
driver.raw_output               # Raw ANSI string
driver.state_data               # Structured Hash with :raw, :rows, :cursor, :size
driver.state_json                # JSON string (includes raw ANSI)
driver.state_json(pretty: true)  # Pretty JSON

# Visual capture
driver.screenshot("screenshot.png")  # PNG renderer
TUITD::HtmlRenderer.new(driver.state_data).render("output.html")  # HTML renderer
html_string = TUITD::HtmlRenderer.new(driver.state_data).to_html   # HTML string

driver.close
```

### State — Analyze terminal content

```ruby
state = TUITD::State.new(driver.state_data)

# Read text
state.plain_text                # "Hello\n> prompt\n"
state.text_at(row, col, length) # Extract substring at position
state.find_text("error")        # [{row: 2, col: 10, text: "error", full_line: "..."}]

# Inspect cells
state.foreground_at(0, 5)       # "cyan"
state.background_at(0, 5)       # "bright_black"
state.style_at(0, 5)            # {bold: true, italic: false, underline: false}

# AI-optimized compact output
state.to_ai_json
# => {
#   size:    {rows: 40, cols: 120},
#   cursor:  {row: 5, col: 12},
#   text:    "> Hello\n...",
#   highlights: [
#     {row: 0, text: "MyApp v1.0.0", bold: true, fg: "cyan"}
#   ],
#   summary: "Cursor at [5,12]. 1 styled row, colors: fg=cyan."
# }
```

### Full example — Test a TUI programmatically

```ruby
require "tui_td"

driver = TUITD::Driver.new("my_tui_app", rows: 24, cols: 80)
driver.start

# Wait for the initial prompt
driver.wait_for_text("> ", timeout: 10)

# Send a command
driver.send("list files\n")
driver.wait_for_stable

# Analyze output
state = TUITD::State.new(driver.state_data)

if state.find_text("ERROR").any?
  puts "Bug found!"
  driver.screenshot("error_proof.png")
end

# Check colors
welcome_fg = state.foreground_at(0, 0)
raise "Expected cyan header" unless welcome_fg == "cyan"

# Send more commands, inspect, loop...
driver.send("/quit\n")
driver.wait_for_exit
driver.close
```

## Testing

tui-td supports two test formats: **JSON** for declarative, framework-agnostic tests, and **RSpec** for Ruby-native tests with custom matchers.

### JSON Test Format

Tests are defined as JSON with a sequence of action steps. Each step maps to a tui-td operation.

Run with the `tui-td test` command:

```bash
tui-td test examples/echo_test.json
```

**Format:**

```json
{
  "name": "My test",
  "rows": 24,
  "cols": 80,
  "timeout": 10,
  "steps": [
    { "start": "my_tui_app" },
    { "wait_for_text": "> " },
    { "send": "hello\n" },
    { "assert_text": "hello" },
    { "assert_fg": [0, 0], "is": "cyan" },
    { "close": true }
  ]
}
```

**Available steps:**

| Step | Key | Description |
|------|-----|-------------|
| `start` | `"command"` | Start a TUI application |
| `send` | `"text"` | Send text (use `\n` for Enter) |
| `send_key` | `"key"` | Send a special key (`enter`, `up`, `ctrl_c`, ...) |
| `wait_for_text` | `"text"` | Wait until text appears |
| `wait_for_stable` | — | Wait until output is stable |
| `assert_text` | `"text"` | Assert that text exists on screen |
| `assert_fg` | `[row, col], "is": "color"` | Assert foreground color |
| `assert_bg` | `[row, col], "is": "color"` | Assert background color |
| `assert_style` | `[row, col], "bold": true` | Assert cell style (bold, italic, underline) |
| `screenshot` | `"path"` | Save PNG screenshot |
| `html` | `"path"` | Save HTML render for browser viewing |
| `close` | — | Close the TUI |

Example with `html` step for before/after snapshots:

```json
{
  "name": "Visual diff test",
  "rows": 40, "cols": 120,
  "steps": [
    { "start": "my_tui_app" },
    { "wait_for_stable": true },
    { "html": "/tmp/before.html" },
    { "send": "Help\n" },
    { "wait_for_stable": true },
    { "html": "/tmp/after.html" },
    { "close": true }
  ]
}
```

**Ruby API:**

```ruby
plan = File.read("test/example.json")
result = TUITD::TestRunner.new(plan).run
puts result[:passed]  # => true
result[:results].each { |r| puts "#{r[:step]}: #{r[:passed]} - #{r[:message]}" }
```

### RSpec Tests

Use custom matchers for expressive, Ruby-native TUI tests:

```ruby
require "tui_td"
require "tui_td/matchers"

RSpec.describe "My TUI" do
  before(:all) do
    @driver = TUITD::Driver.new("my_tui_app", rows: 24, cols: 80)
    @driver.start
  end

  after(:all) { @driver&.close }

  let(:state) { TUITD::State.new(@driver.state_data) }

  it "shows welcome message" do
    expect(state).to have_text("Welcome")
  end

  it "has a cyan header" do
    expect(state).to have_fg("cyan").at(0, 0)
  end

  it "has a blue background on row 3" do
    expect(state).to have_bg("blue").at(3, 0)
  end

  it "has bold text on the first line" do
    expect(state).to have_style.at(0, 0).with(bold: true)
  end
end
```

**Matchers:**

| Matcher | Usage |
|---------|-------|
| `have_text("...")` | Assert text is present on screen |
| `have_fg("color").at(row, col)` | Assert foreground color at position |
| `have_bg("color").at(row, col)` | Assert background color at position |
| `have_style.at(row, col).with(bold: true, ...)` | Assert cell style |

## MCP Server — AI Integration

Start the MCP server to let any MCP client control TUIs:

```bash
tui-td serve
```

### Available tools

| Tool | Description |
|------|-------------|
| `tui_start` | Start a TUI application. Call first. |
| `tui_send` | Send text input. Use `\n` for Enter. |
| `tui_send_key` | Send special keys: `enter`, `tab`, `up`, `down`, `left`, `right`, `escape`, `ctrl_c`, `ctrl_d` |
| `tui_wait_for_text` | Wait until specified text appears in output (with timeout). |
| `tui_wait_for_stable` | Wait until terminal output stabilizes (300ms of silence). |
| `tui_state` | Get terminal state: AI-friendly compact mode (default), `full` grid, or `text` only. |
| `tui_plain_text` | Get plain text content, ANSI stripped. |
| `tui_screenshot` | Capture a PNG screenshot of the current terminal. |
| `tui_close` | Close the TUI and clean up. |

### MCP configuration

Add to your MCP client configuration:

```json
{
  "mcpServers": {
    "tui-td": {
      "command": "tui-td",
      "args": ["serve"]
    }
  }
}
```

### Example MCP session

```json
// 1. Start the TUI
{"method": "tools/call", "params": {"name": "tui_start", "arguments": {"command": "htop"}}}

// 2. Wait for prompt
{"method": "tools/call", "params": {"name": "tui_wait_for_text", "arguments": {"text": "> "}}}

// 3. Send a command
{"method": "tools/call", "params": {"name": "tui_send", "arguments": {"text": "Write hello.rb\n"}}}

// 4. Wait for output
{"method": "tools/call", "params": {"name": "tui_wait_for_stable", "arguments": {}}}

// 5. Get AI-friendly state
{"method": "tools/call", "params": {"name": "tui_state", "arguments": {"format": "ai"}}}

// 6. Take screenshot if needed
{"method": "tools/call", "params": {"name": "tui_screenshot", "arguments": {"path": "/tmp/proof.png"}}}

// 7. Clean up
{"method": "tools/call", "params": {"name": "tui_close", "arguments": {}}}
```

## State Format

Top-level structure returned by `state_data` / `--json`:

```json
{
  "size":   {"rows": 40, "cols": 120},
  "cursor": {"row": 5, "col": 12},
  "rows":   [[{"char": "A", "fg": "cyan", ...}]],
  "raw":    "\e[31mred\e[0m\n..."
}
```

Each cell in the `rows` grid:

```json
{
  "char": "A",
  "fg": "cyan",
  "bg": "default",
  "bold": true,
  "italic": false,
  "underline": false
}
```

`raw` is the original ANSI output with all escape sequences preserved.

### Color value formats

| Format | Example | Description |
|--------|---------|-------------|
| `"default"` | — | Terminal default color |
| Named | `"red"`, `"cyan"` | Standard 16 ANSI colors |
| Bright | `"bright_red"`, `"bright_green"` | Bright 16 ANSI colors |
| 256-color | `"color82"` | XTerm 256-color palette |
| TrueColor | `"#ff6432"` | 24-bit hex RGB |

## Screenshot

Screenshots are rendered using the embedded Spleen 8×16 bitmap font via `chunky_png`. No external tools required (no npm, no ImageMagick). Handles all color formats and styles (bold, italic, underline).

```ruby
# Via CLI
tui-td --screenshot output.png capture "echo 'Hello World'"

# Via Ruby API
driver.screenshot("output.png")
```

## HTML Renderer

Renders terminal state as a self-contained HTML document with inline CSS. Faithfully reproduces colors, bold, italic, underline, and cursor position — so an LLM or human can "see" the TUI in any browser without external dependencies.

Features:
- Dark theme matching terminal appearance
- Run-length encoding of adjacent identically-styled cells (compact HTML)
- Cursor indicator (yellow outline)
- HTML entity escaping (`<`, `>`, `&`, `"`)
- All ANSI color formats: 16 named, bright, 256-color, TrueColor

```bash
# CLI — capture once
tui-td --html output.html capture "htop"

# CLI — run with custom terminal size
tui-td --html /tmp/demo.html run "htop" --rows 40 --cols 120
```

```ruby
# Ruby API — render to file
TUITD::HtmlRenderer.new(driver.state_data).render("output.html")

# Ruby API — get HTML string (e.g. for API responses)
html = TUITD::HtmlRenderer.new(driver.state_data).to_html
```

```json
// Test-Runner — before/after snapshots
{"html": "/tmp/snapshot.html"}
```

## License

MIT
