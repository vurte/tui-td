# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

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
        .cursor-cell.cursor-hidden {
          outline: none !important;
          border: none !important;
          background-color: transparent !important;
          color: inherit !important;
        }
        .cursor-cell.cursor-block {
          outline: none;
          background-color: #fff;
          color: #000 !important;
        }
        .cursor-cell.cursor-block.blink {
          animation: cursor-block-blink 1s step-end infinite;
        }
        .cursor-cell.cursor-underline {
          outline: none;
          border-bottom: 2px solid #fff;
        }
        .cursor-cell.cursor-underline.blink {
          animation: cursor-underline-blink 1s step-end infinite;
        }
        .cursor-cell.cursor-bar {
          outline: none;
          border-left: 2px solid #fff;
        }
        .cursor-cell.cursor-bar.blink {
          animation: cursor-bar-blink 1s step-end infinite;
        }
        @keyframes cursor-block-blink {
          50% { background-color: transparent; color: inherit; }
        }
        @keyframes cursor-underline-blink {
          50% { border-bottom-color: transparent; }
        }
        @keyframes cursor-bar-blink {
          50% { border-left-color: transparent; }
        }
        @keyframes term-blink {
          50% { opacity: 0; }
        }
        .term-blink {
          animation: term-blink 1s step-end infinite;
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
        char = cell[:char] || cell["char"] || " "
        fg = cell[:fg] || cell["fg"] || "default"
        bg = cell[:bg] || cell["bg"] || "default"
        bold = cell[:bold] || cell["bold"] || false
        italic = cell[:italic] || cell["italic"] || false
        underline = cell[:underline] || cell["underline"] || false
        blink = cell[:blink] || cell["blink"] || false

        style_key = [fg, bg, bold, italic, underline, blink]
        is_cur = cursor_at?(ri, ci)

        if current_run && current_run[:key] == style_key && !current_run[:has_cursor] && !is_cur
          current_run[:chars] << char
        else
          current_run = {
            key: style_key,
            chars: [char],
            style: cell_style(fg, bg, bold, italic, underline),
            has_cursor: is_cur,
            blink: blink,
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
      return chars if run[:style].empty? && !run[:has_cursor] && !run[:blink]

      classes = []
      if run[:has_cursor]
        classes << "cursor-cell"
        cursor_vis = @cursor[:visible] != false && @cursor["visible"] != false
        if cursor_vis
          style_val = @cursor[:style] || @cursor["style"]
          case style_val
          when 0, 1
            classes << "cursor-block blink"
          when 2
            classes << "cursor-block"
          when 3
            classes << "cursor-underline blink"
          when 4
            classes << "cursor-underline"
          when 5
            classes << "cursor-bar blink"
          when 6
            classes << "cursor-bar"
          end
        else
          classes << "cursor-hidden"
        end
      end
      classes << "term-blink" if run[:blink]

      cls = classes.empty? ? "" : %( class="#{classes.join(" ")}")
      style = run[:style].empty? ? "" : %( style="#{run[:style]}")
      %(<span#{cls}#{style}>#{chars}</span>)
    end

    def cursor_at?(ri, ci)
      (@cursor[:row] || @cursor["row"]) == ri && (@cursor[:col] || @cursor["col"]) == ci
    end

    def css_color(rgb)
      format("#%<r>02x%<g>02x%<b>02x", r: rgb[0], g: rgb[1], b: rgb[2])
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
# rubocop:enable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
