# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

require "json"
require "fileutils"

module TUITD
  # Named, persisted snapshot for terminal state comparison.
  #
  # First run: saves the snapshot to disk (golden master).
  # Subsequent runs: compares current state against the saved snapshot.
  #
  # Types:
  #   :text  - chars_only comparison (ignores colors/styles), saved as JSON
  #   :full  - full cell comparison (includes colors/styles), saved as JSON
  #   :png   - screenshot PNG, compared byte-by-byte
  #   :html  - HTML render, compared byte-by-byte
  #   :all   - saves/compares all three formats
  #
  # Environment:
  #   UPDATE_SNAPSHOTS=1 — auto-update all snapshots instead of comparing
  #
  class Snapshot
    EXTENSIONS = {
      text: ".json",
      full: ".json",
      png: ".png",
      html: ".html",
    }.freeze

    # Result of a snapshot comparison.
    ComparisonResult = Struct.new(
      :passed, :diff_count, :message, :details, :type,
      keyword_init: true,
    ) do
      def passed?
        passed
      end
    end

    attr_reader :name, :type, :snapshot_dir

    def initialize(name, type: :text, snapshot_dir: nil)
      @name = name.to_s
      @type = type.to_sym
      @snapshot_dir = snapshot_dir || TUITD.configuration.snapshot_dir || "spec/snapshots"
      FileUtils.mkdir_p(@snapshot_dir)
    end

    # Return the full filesystem path for the given extension.
    def path(ext = EXTENSIONS.fetch(@type, ".json"))
      File.join(@snapshot_dir, "#{@name}#{ext}")
    end

    # Check if the primary snapshot file exists on disk.
    def exists?
      if @type == :all
        %i[text png html].all? { |t| File.exist?(path(EXTENSIONS[t])) }
      else
        File.exist?(path)
      end
    end

    # Save terminal state as a named snapshot.
    def save(state_data)
      data = normalize(state_data)

      File.write(path(".json"), JSON.pretty_generate(data)) if save_json?

      Screenshot.new(data).render(path(".png")) if save_png?

      return unless save_html?

      HtmlRenderer.new(data).render(path(".html"))
    end

    # Compare current terminal state against the saved snapshot.
    # Returns ComparisonResult.
    def compare(state_data, ignore_rows: nil, region: nil)
      if @type == :all
        compare_all(state_data, ignore_rows: ignore_rows, region: region)
      elsif png?
        compare_png(state_data)
      elsif html?
        compare_html(state_data)
      else
        compare_json(state_data, chars_only: @type == :text, ignore_rows: ignore_rows, region: region)
      end
    end

    private

    def normalize(state_data)
      return state_data if state_data.is_a?(Hash)

      # Extract hash from State objects
      if state_data.respond_to?(:grid) && state_data.respond_to?(:rows)
        return {
          size: { rows: state_data.rows, cols: state_data.cols },
          cursor: state_data.cursor,
          rows: state_data.grid,
        }
      end

      state_data
    end

    def save_json?
      %i[text full all].include?(@type)
    end

    def save_png?
      %i[png all].include?(@type)
    end

    def save_html?
      %i[html all].include?(@type)
    end

    def png?
      @type == :png
    end

    def html?
      @type == :html
    end

    def compare_json(state_data, chars_only:, ignore_rows: nil, region: nil)
      file = path(".json")
      return missing_file_result(file) unless File.exist?(file)

      begin
        saved = JSON.parse(File.read(file), symbolize_names: true)
      rescue JSON::ParserError => e
        return ComparisonResult.new(
          passed: false, diff_count: 1, type: @type,
          message: "Failed to parse snapshot JSON: #{e.message}",
        )
      end

      current = TUITD::State.new(normalize(state_data))
      saved_state = TUITD::State.new(saved)
      diffs = current.diff(saved_state, chars_only: chars_only)

      # Restrict to specified region first, then remove ignored rows
      if region
        region = Array(region)
        diffs.select! { |d| region.include?(d[:row]) }
      end
      if ignore_rows
        ignored = Array(ignore_rows)
        diffs.reject! { |d| ignored.include?(d[:row]) }
      end

      if diffs.empty?
        ComparisonResult.new(
          passed: true, diff_count: 0, type: @type,
          message: "Snapshot '#{@name}' matches (#{@type})",
        )
      else
        details = diffs.first(20).map do |d|
          {
            row: d[:row], col: d[:col],
            before: d[:before], after: d[:after],
          }
        end
        msg = ["Snapshot '#{@name}' has #{diffs.size} difference(s) (#{@type}):"]
        diffs.first(20).each do |d|
          msg << "  [#{d[:row]},#{d[:col]}] #{d[:before][:char].inspect} -> #{d[:after][:char].inspect}"
        end
        msg << "  ... (truncated)" if diffs.size > 20
        ComparisonResult.new(
          passed: false, diff_count: diffs.size, type: @type,
          message: msg.join("\n"), details: details,
        )
      end
    end

    def compare_png(state_data)
      file = path(".png")
      return missing_file_result(file) unless File.exist?(file)

      expected = File.binread(file)
      tmp = File.join(@snapshot_dir, ".#{@name}_tmp.png")
      Screenshot.new(state_data).render(tmp)
      actual = File.binread(tmp)
      FileUtils.rm_f(tmp)

      if expected == actual
        ComparisonResult.new(
          passed: true, diff_count: 0, type: :png,
          message: "Snapshot '#{@name}' matches (png)",
        )
      else
        ComparisonResult.new(
          passed: false, diff_count: 1, type: :png,
          message: "Snapshot '#{@name}' does not match (png — pixel difference)",
        )
      end
    end

    def compare_html(state_data)
      file = path(".html")
      return missing_file_result(file) unless File.exist?(file)

      expected = File.read(file)
      actual = HtmlRenderer.new(state_data).to_html

      if expected == actual
        ComparisonResult.new(
          passed: true, diff_count: 0, type: :html,
          message: "Snapshot '#{@name}' matches (html)",
        )
      else
        ComparisonResult.new(
          passed: false, diff_count: 1, type: :html,
          message: "Snapshot '#{@name}' does not match (html — content difference)",
        )
      end
    end

    def compare_all(state_data, ignore_rows: nil, region: nil)
      results = []
      results << compare_json(state_data, chars_only: true, ignore_rows: ignore_rows, region: region)
      results << compare_png(state_data)
      results << compare_html(state_data)

      all_passed = results.all?(&:passed?)
      messages = results.map(&:message).join("\n")
      total_diffs = results.sum(&:diff_count)

      ComparisonResult.new(
        passed: all_passed, diff_count: total_diffs, type: :all,
        message: messages,
      )
    end

    def missing_file_result(file)
      ComparisonResult.new(
        passed: false, diff_count: 0, type: @type,
        message: "Snapshot '#{@name}' not found at #{file}",
      )
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
