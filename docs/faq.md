# FAQ / Troubleshooting

## My test passes locally but fails in CI

- Check that the TUI tool is installed in CI (e.g., `vim`, `htop`, `dialog`).
- Check that `TERM` is available (`xterm-256color` is set automatically).
- Check PTY availability: CI containers (Docker) need `script` or `--tty` allocation.
- Use `tui-td capture "your-tool" --html /tmp/debug.html` to visually inspect output.

## Why is `wait_for_stable` timing out?

Interactive TUIs (like `cat`, `vim`, `htop`) never stabilize because they continuously wait for input. For these, use `wait_for_text` or `wait_for` with a specific condition instead:

```json
{ "wait_for_text": "> " }
```

Or in Ruby:

```ruby
driver.wait_for { |state| state.plain_text.include?("menu") }
```

## Colors don't match what I see

Check that your TUI actually outputs the color codes you expect. Some TUIs detect `$TERM` and disable colors for unknown terminals. tui-td sets `TERM=xterm-256color`.

Use `tui-td capture "your-tool"` to see the raw state.

## Does tui-td work on Windows?

Not with the native PTY driver (it uses Ruby's `pty` stdlib, which is Unix-only). A Docker-based runner is planned.

In the meantime, use WSL2 or a Docker container to run tui-td on Windows.

## How do I test a TUI that never exits?

Use `send_key: ctrl_c` or `send: ""` to send Ctrl+C, then wait for the exit:

```json
{ "send_key": "ctrl_c" },
{ "wait_for_exit": true },
{ "assert_exit": 0 }
```

## The screenshot looks wrong (wrong font, missing characters)

Screenshots use the embedded Spleen 8x16 bitmap font for ASCII and Unifont 8x16 for ~2700 Unicode characters (Latin, Greek, Cyrillic, Arabic, Box Drawing, etc.). If your TUI uses characters outside that range (e.g., CJK), install the `cairo` gem for system font rendering:

```bash
gem install cairo
```

## How do I run tests in parallel?

Each test plan starts its own PTY, so you can run multiple JSON tests in parallel:

```bash
tui-td test test1.json &
tui-td test test2.json &
tui-td test test3.json &
wait
```

For RSpec, use `rspec --order defined` or `parallel_tests` gem.

## My test sometimes passes and sometimes fails

This is usually a timing issue. Try:

1. Add `wait_for_stable` after the `start` step
2. Increase the per-step `timeout` value
3. Use `wait_for_text` instead of assuming immediate output
4. Use auto-wait matchers (`expect(driver).to have_text(...)`) instead of immediate checks

## How do I test a specific dialog in a complex TUI?

Use the Selector to find the dialog, then scope queries inside it:

```ruby
state = TUITD::State.new(driver.state_data)
selector = TUITD::Selector.new(state)
dialog = selector.dialogs.first
selector.within(dialog) do |scope|
  expect(scope.buttons.first.text).to eq("OK")
end
```
