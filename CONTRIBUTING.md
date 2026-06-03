# Contributing to tui-td

## Development Setup

```bash
git clone https://github.com/vurte/tui-td.git
cd tui-td
bundle install
```

## Running Tests

```bash
bundle exec rspec              # unit/integration tests
bundle exec ruby test/mcp_smoke_test.rb  # MCP protocol smoke test
```

## Code Quality

```bash
bundle exec rubocop            # style and linting
bundle exec reek               # code smells
bundle exec bundler-audit      # dependency vulnerability check
```

All three run automatically as a pre-commit hook.

## Project Structure

| Directory | Purpose |
|-----------|---------|
| `lib/tui_td/` | Core library: Driver, Matchers, TestRunner, Selector, renderers, CLI, MCP server |
| `spec/` | RSpec test suite |
| `test/` | Standalone smoke tests |
| `examples/` | Example JSON tests and RSpec specs |
| `bin/` | `tui-td` CLI entry point |

## Adding a New JSON Test Step

1. Add the action in `TestRunner#run` case statement
2. Optionally add a private helper method
3. Add RSpec tests in `spec/test_runner_spec.rb`
4. Document the step in `cli.rb` help output (`help_test` method)

## Adding a New RSpec Matcher

1. Define the matcher in `lib/tui_td/matchers.rb`
2. Use `Matchers.auto_wait(actual) { |s| ... }` for auto-wait support
3. Add tests in `spec/matchers_spec.rb`
4. Document in `cli.rb` help output (`help_rspec` method)

## Adding a New Selector Role

1. Add a detection method in `lib/tui_td/selector.rb` (e.g., `detect_menus`)
2. Add the method to `scan` results
3. Add RSpec matcher and JSON step if appropriate
4. Add tests in `spec/selector_spec.rb`

## Pull Request Workflow

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Run `bundle exec rubocop`, `bundle exec reek`, `bundle exec rspec`
5. Submit a PR with a clear description

## Release Process

1. Update `CHANGELOG.md` with the new version's changes
2. Bump `VERSION` in `lib/tui_td/version.rb`
3. Sync `README.md` CLI Reference with `tui-td --help` output
4. Commit, tag, and push
5. Create a GitHub Release via `gh release create`
