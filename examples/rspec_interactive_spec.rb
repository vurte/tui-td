#!/usr/bin/env ruby
# frozen_string_literal: true

# RSpec example: testing an interactive TUI application.
#
# Demonstrates realistic multi-step interaction patterns:
#   start process → wait for UI → send input → wait for response → assert
#
# Usage: rspec examples/rspec_interactive_spec.rb

require "tui_td"
require "tui_td/matchers"

RSpec.describe "Login form (interactive TUI)" do
  let(:driver) do
    TUITD::Driver.new(
      "ruby examples/login_form.rb",
      rows: 12,
      cols: 40,
      timeout: 10,
    )
  end

  after do
    driver&.close
  end

  it "completes a full login flow" do
    # Start the application and wait for the form to render
    driver.start
    expect(driver).to have_text("Login Form")
    expect(driver).to have_text("Username")
    expect(driver).to have_button("Submit")

    # Type the username
    driver.send("Alice\n")
    expect(driver).to have_text("Alice")

    # Type the password
    driver.send("s3cret!\n")

    # Verify the welcome screen
    expect(driver).to have_text("Login successful!")
    expect(driver).to have_text("Welcome, Alice!")
    expect(driver).to have_text("Password is 7 chars.")

    # Verify welcome text uses green foreground
    expect(driver).to have_fg("green").at(2, 0)
  end
end
