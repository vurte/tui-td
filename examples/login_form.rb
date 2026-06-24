#!/usr/bin/env ruby
# frozen_string_literal: true

# Interactive login form — pure Ruby, no dependencies.
# Used by tui-td examples to demonstrate realistic TUI testing.
#
# Usage: ruby examples/login_form.rb
#   The form prompts for username and password, then shows a welcome screen.

$stdout.sync = true

def cls = print("\e[2J\e[H")

# ---------- Render the login form ----------
cls
print "\e[44;37m  Login Form  \e[0m\n"
print "\n"
print "Username: [                    ]\n"
print "Password: [                    ]\n"
print "\n"
print "     \e[7m[ Submit ]\e[0m  \e[7m[ Cancel ]\e[0m\n"
print "\e[3;11H"  # position cursor in Username field

# ---------- Read username ----------
username = $stdin.gets.chomp
print "\e[3;11H#{username.ljust(20)}"

# ---------- Read password ----------
print "\e[4;11H"  # position cursor in Password field
password = $stdin.gets.chomp

# Show masked password
masked = "*" * password.length
print "\e[4;11H#{masked.ljust(20)}"

sleep 0.3

# ---------- Show welcome screen ----------
cls
print "\e[32m"  # green
print "──────────────────────────────────\n"
print "\n"
print "  Login successful!\n"
print "\n"
print "  Welcome, #{username.strip}!\n"
print "\n"
print "  Password is #{password.length} chars.\n"
print "\n"
print "──────────────────────────────────\n"
print "\e[0m"
sleep 1
