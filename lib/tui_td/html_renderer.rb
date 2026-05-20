# frozen_string_literal: true

require_relative "ansi_utils"

module TUITD
  # Renders terminal state as a self-contained HTML document.
  # Faithfully reproduces what a TUI application shows — colors, styles,
  # cursor position — so an LLM or human can "see" the terminal.
  class HtmlRenderer
    include ANSIUtils

    def initialize(state)
      @state = state
      @rows = _dig(state, :size, :rows) || 40
      @cols = _dig(state, :size, :cols) || 120
      @grid = state[:rows] || state["rows"] || []
      @cursor = state[:cursor] || state["cursor"] || { row: 0, col: 0 }
    end

    # Return HTML string
    def to_html
      css = render_css
      body = render_body
      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>TUI Terminal</title>
        <style>#{css}</style>
        </head>
        <body>#{body}</body>
        </html>
      HTML
    end

    # Write HTML to a file
    def render(output_path)
      File.write(output_path, to_html)
      output_path
    end

    private

    def render_css
      <<~CSS
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          background: #111;
          color: #{css_color(DEFAULT_FG)};
          font-family: "SF Mono", "Fira Code", "Cascadia Code", "JetBrains Mono", "DejaVu Sans Mono", "Menlo", "Monaco", "Courier New", monospace;
          font-size: 14px;
          line-height: 1.3;
          padding: 16px;
        }
        .term {
          display: inline-block;
          background: #{css_color(DEFAULT_BG)};
          border: 1px solid #333;
          border-radius: 4px;
          padding: 8px;
        }
        .line {
          white-space: pre;
          line-height: 1.3;
          min-height: 1.3em;
        }
        .cursor-cell {
          outline: 2px solid #ff0;
          outline-offset: -1px;
          z-index: 1;
          position: relative;
        }
      CSS
    end

    def render_body
      lines = @grid.map.with_index do |row, ri|
        line_html = if row.nil? || row.empty?
          '<span class="line"></span>'
        else
          runs = build_runs(row, ri)
          spans = runs.map do |run|
            render_run(run)
          end
          %(<span class="line">#{spans.join}</span>)
        end
        line_html
      end

      %(<pre class="term">\n#{lines.join("\n")}\n</pre>)
    end

    def build_runs(row, ri)
      runs = []
      current_run = nil

      row.each_with_index do |cell, ci|
        char = (cell[:char] || cell["char"] || " ")
        fg = cell[:fg] || cell["fg"] || "default"
        bg = cell[:bg] || cell["bg"] || "default"
        bold = cell[:bold] || cell["bold"] || false
        italic = cell[:italic] || cell["italic"] || false
        underline = cell[:underline] || cell["underline"] || false

        style_key = [fg, bg, bold, italic, underline]

        if current_run && current_run[:key] == style_key
          current_run[:chars] << char
        else
          current_run = {
            key: style_key,
            chars: [char],
            style: cell_style(fg, bg, bold, italic, underline),
            has_cursor: is_cursor?(ri, ci)
          }
          runs << current_run
        end
      end

      runs
    end

    def cell_style(fg, bg, bold, italic, underline)
      parts = []
      parts << "color:#{css_color(resolve_color(fg, DEFAULT_FG))}"
      parts << "background-color:#{css_color(resolve_color(bg, DEFAULT_BG))}" unless bg == "default"
      parts << "font-weight:bold" if bold
      parts << "font-style:italic" if italic
      parts << "text-decoration:underline" if underline
      parts.join(";")
    end

    def render_run(run)
      chars = run[:chars].map { |c| escape_html(c) }.join
      return chars if run[:style].empty? && !run[:has_cursor]

      classes = []
      classes << "cursor-cell" if run[:has_cursor]
      cls = classes.empty? ? "" : %( class="#{classes.join(" ")}")
      style = run[:style].empty? ? "" : %( style="#{run[:style]}")
      %(<span#{cls}#{style}>#{chars}</span>)
    end

    def is_cursor?(ri, ci)
      @cursor[:row] == ri && @cursor[:col] == ci
    end

    def css_color(rgb)
      format("#%02x%02x%02x", *rgb)
    end

    def escape_html(char)
      case char
      when "&" then "&amp;"
      when "<" then "&lt;"
      when ">" then "&gt;"
      when '"' then "&quot;"
      else char
      end
    end

  end
end
