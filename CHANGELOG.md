# CHANGELOG

## 0.2.19

### Added

- Minitest integration: `TUITD::Minitest::Assertions` module with 34 assertion methods
  (17 assert + 17 refute) covering text, regex, colors, styles, exit status, all 9
  element roles, and named snapshots with region/ignore_rows support
- Auto-wait for Minitest: Driver assertions wait up to 3s, State checks immediately
- `tui-td help minitest` — complete assertion reference
- Example: `examples/minitest_example_test.rb` with 7 test cases
- Smoke test: `test/minitest_smoke_test.rb` (10 runs, 19 assertions)

### Changed

- Updated gemspec metadata (summary, description) for rubygems.org

## 0.2.18

(yanked — same as 0.2.19 but with outdated gemspec metadata)

## 0.2.17

### Added

- Named snapshot testing: `match_snapshot("name")` — first run creates golden master,
  subsequent runs compare. Supports `type: :text` (chars_only), `:full`, `:png`, `:html`, `:all`.
- `ignore_rows:` parameter — skip specific rows during snapshot comparison
- `region:` parameter — restrict comparison to a row range (e.g., `region: 0..6`)
  Combinable with `ignore_rows:` for fine-grained control.
- `UPDATE_SNAPSHOTS=1` — environment variable to auto-update all snapshots
- `TUITD.configure { |c| c.snapshot_dir = "..." }` — configurable snapshot directory
- `Driver#find_text(pattern, match:)` — convenience delegation to State#find_text
- `Driver#snapshot` — returns a State snapshot for in-memory comparison
- JSON test steps: `snapshot`, `assert_snapshot` with `type:` and `wait:` options
- MCP tools: `tui_save_snapshot`, `tui_assert_snapshot`, `tui_element_actions`,
  `tui_annotate_element`, `tui_diff`
- Drive mode: `snapshot <name>`, `diff <name>` commands
- `TUITD::Snapshot` class — core abstraction for save/load/compare of named snapshots
- `TUITD::Configuration` class — global gem configuration

### Changed

- `match_snapshot` matcher: now accepts String names (named snapshots) in addition to
  legacy State objects. New kwargs: `type:`, `wait:`, `ignore_rows:`, `region:`.
- `tui_find_text` MCP tool: added `match:` parameter (`partial`, `exact`, `regex`)
- `tui_find_elements` MCP tool: added `checked:`/`disabled:` filters, new roles
- `tui_diff` MCP tool: fixed deep key symbolization for snapshot hash compatibility
- Dependency: tans-parser `~> 0.1.3`

## 0.2.16

### Added

- Driver#find_text: convenience delegation to State#find_text with match: modes
- Driver#snapshot: return a State snapshot for later diff comparison
- match_snapshot RSpec matcher: compare current state against saved snapshot,
  supports chars_only: true to ignore color/style changes
- MCP tui_diff tool: compare current terminal state against a previous snapshot,
  returns cell-level differences
- MCP tui_annotate_element tool: manually register UI element annotations that
  are picked up by tui_find_elements
- Drive mode: snapshot and diff commands for interactive state comparison

### Changed

- Tighten tans-parser dependency to ~> 0.1.3 (includes State#diff,
  State#annotate_role, improved dialog/statusbar detection)

## 0.2.15

### Added

- Integration with tans-parser 0.1.2: new UI element roles (:input, :label, :menu, :tab)
- Filter kwargs on get_by_role: text:, checked:, disabled:
- Singular convenience methods: button(), checkbox(), input(), label(), menu(), tab(),
  dialog(), statusbar(), progress_bar()
- Element action methods: click, type(text), press_key(key)
- Element predicates: checked?, disabled?
- Element bounds accessor
- disabled field on Element
- ScopedSelector via Selector#within(element, &block) with full query API
- State#find_text match modes: :partial (default), :exact, :regex
- RSpec matchers: have_input, have_label, have_menu, have_tab, have_statusbar,
  have_progress_bar
- JSON test steps: assert_input, assert_label, assert_menu, assert_tab,
  assert_statusbar, assert_progress_bar
- MCP tool: tui_element_actions — returns click/type/press_key action hashes
- Enhanced MCP tui_find_elements: checked/disabled filters, new roles, (disabled)/
  (focused) output
- Enhanced MCP tui_find_text: match: parameter for exact/regex mode
- CLI drive mode: elements command now shows inputs, labels, menus, tabs
- Updated help texts (tui-td help test, tui-td help rspec) with new steps and matchers

### Changed

- RSpec matchers (have_button, have_checkbox, have_role) now use tans-parser filter
  kwargs instead of manual .select post-filtering
- JSON test runner check_role helper uses tans-parser filter kwargs
- have_checkbox now supports .unchecked chain

### Removed

- Custom coordinate-based Selector#within (replaced by tans-parser's element-based
  within with ScopedSelector)

## 0.2.14

### Fixed

- Tighten tans-parser dependency from `~> 0.1` to `~> 0.1.1` to ensure the required
  Selector/Element classes are present (0.1.0 lacks them)

## 0.2.13

### Added

- Auto-wait mechanisms: `Driver#wait_for(predicate)` with adaptive polling (10ms → 100ms),
  auto-wait on RSpec matchers (3s timeout when given a Driver), auto-wait on JSON test
  assertions (2s per-check timeout)
- Semantic selectors: `Element` struct and `Selector` class with heuristic role detection
  for buttons, checkboxes, dialogs, statusbars, and progress bars
- RSpec matchers: `have_button`, `have_dialog`, `have_checkbox`, `have_role`
- JSON test steps: `assert_button`, `assert_dialog`, `assert_checkbox`, `assert_role`
- `within` scoping for filtering elements by bounding box
- `poll_interval` parameter on Driver for configurable polling speed

### Changed

- `wait_for_stable` uses buffer-size tracking instead of full grid parse for performance
- Output buffer capped at 10 MB (ring buffer) to prevent unbounded memory growth
- Delegate `Selector` and `Element` to tans-parser 0.1.1

### Documentation

- Add CONTRIBUTING.md with development setup, code quality, and PR workflow
- Add docs/quick_start.md with 2-minute getting-started tutorial
- Add docs/faq.md covering 8 common troubleshooting topics
- Add whiptail dialog example (`examples/whiptail_dialog.json`)
- Update CLI help (`tui-td help test`, `tui-td help rspec`) with new steps and matchers

## 0.2.12

### Security

- Command injection prevention: use Shellwords.shellsplit + array form of PTY.spawn
- Environment variable sanitization: block dangerous vars (PATH, LD_PRELOAD, etc.)
- Path traversal prevention: validate output paths for screenshot/HTML
- ReDoS prevention: add regex timeout in find_text

### Fixed

- ANSI erase operations (ED/EL) now reset all cell attributes (fg, bg, bold, italic,
  underline), not just the character — colors and styles no longer leak across lines

### Architecture

- Extract ANSIParser, ANSIUtils, and State into standalone tans-parser gem (v0.1.0)
- Add tans-parser as a runtime dependency (~>0.1)
- Replace extracted unit tests with forwarder integration smoke tests

## 0.2.11

- Add RuboCop (rubocop-rake, rubocop-rspec), Reek, and Bundler-Audit linters
- Pre-commit hook runs all three checks automatically
- Fix dead code after `raise` in test_runner.rb
- Rename `is_cursor?` to `cursor_at?` in html_renderer.rb
- Merge duplicate `describe "#find_text"` blocks in state_spec.rb
- Fix ANSI parser `FormatStringToken` warnings

## 0.2.10

- Three new MCP tools: `tui_wait_for_exit` (wait for process to end), `tui_exit_status` (get exit code), `tui_find_text` (search terminal state for text/regex matches)
- Document `tui_html_render` MCP tool in README (was already implemented but missing from docs)
- Smoke test expanded to 63 assertions covering all 13 MCP tools including new ones

## 0.2.9

- Fix: `wait_for_stable` uses parsed terminal grid comparison instead of raw byte arrival, preventing interactive TUIs that repaint cell-by-cell (e.g., glow) from timing out
- Fix: `cmd_capture` catches timeout for interactive TUIs and proceeds with whatever was rendered
- New tests for `driver.rb` (39), `cli.rb` (19), and `mcp/server.rb` (27) — 85 new tests total

## 0.2.8

- Unicode bitmap font in screenshot renderer: 2766 glyphs from GNU Unifont 17.0.04 covering Latin, Greek, Cyrillic, Arabic, Turkish, Math, Arrows, Box Drawing, Symbols, and Dingbats
- Cairo renderer as optional fallback for characters not in Unifont (e.g. CJK), with 3x supersampling and box-filter downsampling for sharp edges
- Rendering priority: Spleen (ASCII 33–126) → Unifont (127+, 2766 glyphs) → Cairo (fallback)
- Full test coverage for Unifont glyphs and Cairo renderer

## 0.2.7

- Screenshot rendering for 23 special characters: blocks (▀ ▄ █), triangles (▲ ▼), arrows (↑ ↓ → ←), half blocks (▌ ▐)
- Screenshot rendering for symbols: checkmarks (✓ ✗ ✖), checkboxes (☐ ☑ ☒), gear (⚙), warning (⚠), info (ℹ)
- Screenshot rendering for punctuation: ellipsis (…), em dash (—)
- Cursor drawing support in screenshot renderer
- Braille character rendering in screenshot
- Rounded corner box-drawing characters (╭ ╮ ╯ ╰) in screenshot
- `page_up` / `page_down` key support in test runner and driver
- Fixed junction pixels in rounded corner box-drawing characters

## 0.2.6

- ISO-2022 charset switching support (G0/G1 designators, Shift Out/In) with DEC Special Character & Line Drawing mapping
- SGR mouse reporting mode parsing (1000, 1002, 1003, 1006)
- Mouse reporting and cursor visibility/style reconstruction in build_frame
- Fixed `state_data` in `driver.rb` to unconditionally refresh terminal state instead of returning stale cache
- New `cursor_visible`, `cursor_style`, `mouse_mode`, `mouse_format` attributes on `State`
- HTML and screenshot styling for new cursor/mouse attributes

## 0.2.5

- MCP smoke test expanded: 20 → 54 assertions, covers all 10 tools plus error paths (88% server coverage)
- Extracted `ansi_utils.rb` — shared ANSI helpers used by parser, renderer, and screenshot
- New RSpec specs for `ansi_utils`, enhanced specs for `test_runner`, `html_renderer`, `matchers`, `state`, `ansi_parser`

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
