#!/usr/bin/env ruby
# frozen_string_literal: true

# Minitest example: testing an interactive TUI application.
#
# Demonstrates realistic multi-step interaction patterns:
#   start process → wait for UI → send input → wait for response → assert
#
# Usage: ruby examples/minitest_interactive_test.rb

require "bundler/setup"
require "minitest/autorun"
require "tui_td"
require "tui_td/minitest/assertions"

class LoginFormTest < Minitest::Test
  include TUITD::Minitest::Assertions

  def setup
    @driver = TUITD::Driver.new(
      "ruby examples/login_form.rb",
      rows: 12,
      cols: 40,
      timeout: 10,
    )
    @driver.start
  end

  def teardown
    @driver&.close
  end

  def test_form_renders_correctly
    assert_text(@driver, "Login Form")
    assert_text(@driver, "Username")
    assert_text(@driver, "Password")
    assert_button(@driver, "Submit")
    assert_button(@driver, "Cancel")
  end

  def test_full_login_flow
    # Type username and verify it appears
    @driver.send("Alice\n")
    @driver.wait_for_text("Alice")
    assert_text(@driver, "Alice")

    # Type password and verify welcome screen
    @driver.send("s3cret!\n")
    @driver.wait_for_text("Login successful!")

    assert_text(@driver, "Welcome, Alice!")
    assert_text(@driver, "Password is 7 chars.")
    assert_fg(@driver, "green", row: 2, col: 0)
  end

  def test_refute_unexpected_text
    assert_text(@driver, "Login Form")
    refute_text(@driver, "Error")
    refute_text(@driver, "Failed")
  end
end
