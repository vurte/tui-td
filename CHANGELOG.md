# CHANGELOG

## 0.2.4

- `assert_regex` JSON test step — match terminal output against a Ruby regex
- `assert_not_text` JSON test step — fail if text IS present (inverse of assert_text)
- `have_regex` RSpec matcher — regex assertions in spec files
- `have_text` negation in RSpec: `expect(state).not_to have_text("Error")`
- README step reference table updated (all 13 step types listed)

## 0.2.3

- `have_exit_status` RSpec matcher and `exitstatus` drive command — exit code testing on all three levels (JSON + RSpec + drive)
- `env` in start step — inject environment variables per test run
- Per-step `timeout` override
- `before_all` / `after_all` hooks for setup and teardown steps

## 0.2.2

- `wait_for_exit` and `assert_exit` JSON test steps — test process exit codes

## 0.2.1

- `Driver#refresh` — explicit state re-parse for MCP server clients

## 0.2.0

- Live debug modes for `tui-td test`: `-v` (verbose), `-l` (live screen-refresh), `-s` (step-by-step pause)
- Fix: skip DEC private mode sequences (`\e[?1049h` alternate screen, `\e[?25h` cursor visibility, etc.)
- TestRunner `on_step` callback API for programmatic step-by-step observation
- Vim interaction test example: type, yank, paste, substitute
- Removed aruba dev dependency from Gemfile

## 0.1.3

- UTF-8 multi-byte character support in ANSI parser (`_utf8_char_at`)
- `--help` is now a complete CLI reference: Examples section, interactive drive commands
- `tui-td help test` — JSON test step reference with CLI and Ruby code workflow
- `tui-td help rspec` — RSpec matchers reference with Driver/State setup workflow
- `--version` flag

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
