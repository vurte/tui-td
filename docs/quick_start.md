# Quick Start

Get your first TUI test running in 2 minutes.

## Install

```bash
gem install tui-td
```

## Your First Test

Create `hello.json`:

```json
{
  "name": "Hello World",
  "steps": [
    { "start": "echo hello world" },
    { "wait_for_stable": true },
    { "assert_text": "hello" },
    { "close": true }
  ]
}
```

Run it:

```bash
tui-td test hello.json
```

You should see all steps pass. That's it.

## Your First RSpec Test

Create `hello_spec.rb`:

```ruby
require "tui_td"
require "tui_td/matchers"

RSpec.describe "Hello World" do
  it "prints hello" do
    driver = TUITD::Driver.new("echo hello world", rows: 3, cols: 40)
    driver.start
    expect(driver).to have_text("hello")
    driver.close
  end
end
```

Run with `bundle exec rspec hello_spec.rb`.

## Auto-Wait

Matchers automatically wait when given a `Driver`:

```ruby
driver = TUITD::Driver.new("slow-command", timeout: 10)
driver.start

# Waits up to 3 seconds for "Ready" to appear
expect(driver).to have_text("Ready")

# Waits up to 3 seconds for the color condition
expect(driver).to have_fg("green").at(2, 5)

driver.close
```

You can also wait explicitly:

```ruby
driver.wait_for { |state| state.find_text("Ready").any? }
driver.wait_for(timeout: 5) { |state| state.foreground_at(0, 0) == "cyan" }
```

## Semantic Selectors

Find UI elements by role:

```ruby
state = TUITD::State.new(driver.state_data)
selector = TUITD::Selector.new(state)

selector.buttons      # => [Element("OK"), Element("Cancel")]
selector.checkboxes   # => [Element("Enable", checked: true)]
selector.dialogs      # => [Element(dialog text)]
selector.inputs       # => [Element(input field)]
selector.labels       # => [Element("Username:"), Element("Password:")]
selector.menus        # => [Element("File | Edit | View")]
selector.tabs         # => [Element("File"), Element("Edit")]
selector.statusbars   # => [Element(status text)]
selector.progress_bars # => [Element("50%")]

# Scoped queries inside a dialog
dialog = selector.dialogs.first
selector.within(dialog) do |scope|
  scope.buttons  # only buttons inside the dialog
end
```

RSpec matchers for selectors:

```ruby
expect(state).to have_button("OK")
expect(state).to have_dialog
expect(state).to have_checkbox("Enable").checked
expect(state).to have_input
expect(state).to have_label("Username")
expect(state).to have_menu
expect(state).to have_tab("File")
expect(state).to have_statusbar
expect(state).to have_progress_bar("50%")
expect(state).to have_role(:button, text: "OK")
```

## Screenshots

```ruby
driver.screenshot("/tmp/screen.png")  # PNG of current state
```

Or from CLI:

```bash
tui-td capture "echo hello" --screenshot /tmp/out.png
```

## Visual Debugging

```bash
tui-td capture "your-tui-command" --html /tmp/debug.html
open /tmp/debug.html
```

## What's Next

- Read `tui-td --help` for the full CLI reference
- Read `tui-td help test` for all JSON test step types
- Read `tui-td help rspec` for all RSpec matchers
- Check `examples/` for more advanced test scenarios
