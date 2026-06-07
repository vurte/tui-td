# frozen_string_literal: true

# rubocop:disable Metrics/CyclomaticComplexity, Naming/PredicateMethod

require "English"

module TUITD
  # Records TUI sessions as video using ffmpeg.
  #
  # Frames are captured via the existing Screenshot pipeline and piped
  # directly to ffmpeg's stdin as PNG images — no temporary frame files.
  #
  # Usage:
  #   recorder = VideoRecorder.new("session.mp4", driver: driver, framerate: 30)
  #   recorder.start
  #   # ... interact with TUI ...
  #   recorder.stop  # => "session.mp4"
  #
  class VideoRecorder
    QUALITY_CRF = {
      "high" => 18,
      "medium" => 23,
      "low" => 28,
    }.freeze

    DEFAULT_QUALITY = "high"
    DEFAULT_FRAMERATE = 30
    DEFAULT_CODEC = "libx264"

    attr_reader :output_path, :framerate, :codec, :quality

    def initialize(output_path, driver:, framerate: DEFAULT_FRAMERATE,
                   codec: DEFAULT_CODEC, quality: DEFAULT_QUALITY)
      raise Error, "ffmpeg not found. Install ffmpeg to use video recording." unless self.class.available?

      @output_path = File.expand_path(output_path)
      @driver = driver
      @framerate = framerate
      @codec = codec
      @quality = quality
      @ffmpeg_io = nil
      @capture_thread = nil
      @running = false
      @mutex = Mutex.new
      @frame_interval = 1.0 / framerate
    end

    # Check whether ffmpeg is available on the system.
    def self.available?
      system("which ffmpeg > /dev/null 2>&1")
    end

    # Start recording. Spawns ffmpeg and begins frame capture.
    def start
      @mutex.synchronize do
        raise Error, "Recording already in progress" if @running

        @ffmpeg_io = IO.popen(ffmpeg_command, "w", err: File::NULL)
        @running = true
      end

      @capture_thread = Thread.new { capture_loop }
      true
    end

    # Stop recording. Waits for ffmpeg to finalize and returns the output path.
    def stop
      @mutex.synchronize do
        return nil unless @running

        @running = false
      end

      @capture_thread&.join(5)
      begin
        @capture_thread&.kill
      rescue StandardError
        nil
      end
      @capture_thread = nil

      begin
        @ffmpeg_io&.close_write
        @ffmpeg_io&.close
      rescue StandardError
        nil
      end
      @ffmpeg_io = nil

      @output_path
    end

    # Is recording currently active?
    def recording?
      @mutex.synchronize { @running }
    end

    private

    def ffmpeg_command
      crf = QUALITY_CRF.fetch(@quality, QUALITY_CRF[DEFAULT_QUALITY])
      ffmpeg_bin = TUITD.configuration.ffmpeg_path || "ffmpeg"

      [
        ffmpeg_bin,
        "-y",                # overwrite output
        "-f", "image2pipe",  # input format: pipe of images
        "-vcodec", "png",    # input codec
        "-r", @framerate.to_s, # input framerate
        "-i", "-",           # read from stdin
        "-vcodec", @codec,   # output codec
        "-crf", crf.to_s,    # quality (lower = better)
        "-pix_fmt", "yuv420p", # wide compatibility
        @output_path,
      ]
    end

    def capture_loop
      last_frame = nil

      while recording?
        loop_start = monotonic

        begin
          state = @driver.state_data
          screenshot = Screenshot.new(state)
          png_blob = screenshot.to_blob

          # Only write frames that differ from the last one (delta compression)
          if last_frame.nil? || png_blob != last_frame
            @ffmpeg_io&.write(png_blob)
            @ffmpeg_io&.flush
            last_frame = png_blob
          end
        rescue IOError, Errno::EPIPE
          break # ffmpeg pipe closed
        rescue StandardError => e
          warn "[tui-td VideoRecorder] Frame capture error: #{e.class}: #{e.message}"
        end

        elapsed = monotonic - loop_start
        sleep_time = @frame_interval - elapsed
        sleep(sleep_time) if sleep_time.positive?
      end
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end

# rubocop:enable Metrics/CyclomaticComplexity, Naming/PredicateMethod
