# frozen_string_literal: true

# Example: Video Recording in RSpec
#
# Run with:
#   bundle exec rspec examples/rspec_recording_example_spec.rb
#
require "tui_td"
require "tui_td/matchers"

RSpec.describe "Video Recording" do
  before(:all) do
    skip "ffmpeg not available" unless TUITD::VideoRecorder.available?

    @video_path = "/tmp/rspec_recording_example_#{Process.pid}.mp4"

    @driver = TUITD::Driver.new("echo 'Hello from RSpec recording!' && sleep 0.5 && echo 'Done.'", rows: 5, cols: 30, timeout: 10)
    @driver.start
    @driver.wait_for_text("Hello")
  end

  after(:all) do
    @driver&.stop_recording
    @driver&.close
    FileUtils.rm_f(@video_path) if @video_path
  end

  it "can start and stop video recording" do
    @driver.start_recording(@video_path, framerate: 2, codec: "libx264")

    expect(@driver).to be_recording

    @driver.wait_for_text("Done")
    @driver.stop_recording

    expect(@driver).not_to be_recording
    expect(@driver).to have_recorded_video(@video_path)
  end
end
