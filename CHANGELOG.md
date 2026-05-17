# CHANGELOG

## 0.1.2

- Background reader thread — continuous PTY reads prevent buffer overflow
- Thread-safe output buffer with Mutex protection
- DSR (Device Status Report) support — respond to `\e[6n` cursor position requests
- Replace `IO.select`/`readpartial` with `read_nonblock`

## 0.1.1

- Add `--chdir` / `-C` CLI flag for running commands in a specific directory
- Default `capture` output to text instead of full JSON grid
- Use `permute!` for CLI option parsing so global flags work after the command
- Fix: skip ISO 2022 charset sequences (`ESC(B`) instead of leaking `(B` into output
- Add `raw` field to state JSON (original ANSI with all escape sequences preserved)
- Publish to rubygems.org

## 0.1.0

- PTY-based TUI driver with `start`, `send`, `send_keys`, `wait_for_text`, `wait_for_stable`
- ANSI parser: SGR colors (16, 256, TrueColor), cursor movement, erase, scroll
- Structured state output: `{size, cursor, rows, raw}`
- CLI: `capture`, `run`, `drive`, `test`, `serve`
- Pure Ruby PNG screenshots via `chunky_png` with embedded Spleen 8×16 font
- HTML renderer with run-length encoding
- JSON test runner with 12 step types
- RSpec matchers: `have_text`, `have_fg`, `have_bg`, `have_style`
- MCP server (JSON-RPC over stdio) for AI-driven TUI testing
