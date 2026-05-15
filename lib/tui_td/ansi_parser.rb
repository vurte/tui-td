# frozen_string_literal: true

module TUITD
  # Parses raw terminal output (ANSI escape sequences + text) into a
  # structured state representation.
  #
  # Handles:
  # - SGR (Select Graphic Rendition) — colors, bold, italic, underline
  # - Cursor movement (CUU, CUD, CUF, CUB, CUP)
  # - Erase (ED, EL)
  # - Line feed, carriage return, backspace, tab
  #
  # Output: {rows: [[{char, fg, bg, bold, italic, underline}]], cursor: {row, col}, size: {rows, cols}}
  #
  module ANSIParser
    SGR_COLORS = {
      0  => :reset,
      1  => :bold,
      3  => :italic,
      4  => :underline,
      5  => :blink,
      7  => :reverse,
      22 => :normal,
      23 => :no_italic,
      24 => :no_underline,
      30 => :black,
      31 => :red,
      32 => :green,
      33 => :yellow,
      34 => :blue,
      35 => :magenta,
      36 => :cyan,
      37 => :white,
      38 => :xterm_fg,  # 38;5;N or 38;2;R;G;B
      39 => :default_fg,
      40 => :bg_black,
      41 => :bg_red,
      42 => :bg_green,
      43 => :bg_yellow,
      44 => :bg_blue,
      45 => :bg_magenta,
      46 => :bg_cyan,
      47 => :bg_white,
      48 => :xterm_bg,  # 48;5;N or 48;2;R;G;B
      49 => :default_bg,
      90 => :bright_black,
      91 => :bright_red,
      92 => :bright_green,
      93 => :bright_yellow,
      94 => :bright_blue,
      95 => :bright_magenta,
      96 => :bright_cyan,
      97 => :bright_white,
      100 => :bg_bright_black,
      101 => :bg_bright_red,
      102 => :bg_bright_green,
      103 => :bg_bright_yellow,
      104 => :bg_bright_blue,
      105 => :bg_bright_magenta,
      106 => :bg_bright_cyan,
      107 => :bg_bright_white,
    }.freeze

    SGR_16_TO_NAME = {
      0  => "black",
      1  => "red",
      2  => "green",
      3  => "yellow",
      4  => "blue",
      5  => "magenta",
      6  => "cyan",
      7  => "white",
      8  => "bright_black",
      9  => "bright_red",
      10 => "bright_green",
      11 => "bright_yellow",
      12 => "bright_blue",
      13 => "bright_magenta",
      14 => "bright_cyan",
      15 => "bright_white",
    }.freeze

    # Parse raw terminal output into a structured state Hash
    def self.parse(raw, rows = 40, cols = 120)
      grid = Array.new(rows) do
        Array.new(cols) do
          { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false }
        end
      end

      cursor = { row: 0, col: 0 }
      attrs = { fg: "default", bg: "default", bold: false, italic: false, underline: false }
      saved_cursor = nil
      scroll_region = nil
      pending_dsr = false

      # Strip everything before the last full clear (if any)
      # to avoid accumulated garbage
      processed = raw

      i = 0
      while i < processed.length
        if processed[i] == "\e" && processed[i + 1] == "["
          # Find end of CSI sequence
          j = i + 2
          j += 1 while j < processed.length && !processed[j].match?(/[A-HJ-KP-SX@`fmnR]/)
          seq = processed[i..j]

          dsr = _apply_csi(seq, cursor, attrs, grid, rows, cols)
          pending_dsr ||= dsr

          i = j + 1
        elsif processed[i] == "\n" || processed[i] == "\r\n"
          cursor[:row] += 1
          cursor[:col] = 0
          i += processed[i..i + 1] == "\r\n" ? 2 : 1
        elsif processed[i] == "\r"
          cursor[:col] = 0
          i += 1
        elsif processed[i] == "\t"
          cursor[:col] = ((cursor[:col] / 8) + 1) * 8
          cursor[:col] = cols - 1 if cursor[:col] >= cols
          i += 1
        elsif processed[i] == "\b"
          cursor[:col] -= 1 if cursor[:col] > 0
          i += 1
        elsif processed[i] == "\a"
          # Bell — ignore
          i += 1
        elsif processed[i] == "\e"
          # Skip escape sequences:
          #   CSI: \e[... (already handled above)
          #   ISO 2022 charset: \e( B  \e) 0  etc. (3 chars total)
          #   Other: just the ESC
          if processed[i + 1] && processed[i + 1].match?(/[()*+\-.\/]/)
            i += 3
          else
            i += 1
          end
        elsif processed[i] =~ /[[:print:]]/
          # Printable character
          if cursor[:row] < rows && cursor[:col] < cols
            cell = grid[cursor[:row]][cursor[:col]]
            cell[:char] = processed[i]
            cell.merge!(attrs)
            cursor[:col] += 1
            cursor[:col] = cols - 1 if cursor[:col] >= cols
          end
          i += 1
        else
          i += 1
        end

        # Handle scrolling
        if cursor[:row] >= rows
          scroll_lines = cursor[:row] - rows + 1
          grid.shift(scroll_lines)
          scroll_lines.times do
            grid << Array.new(cols) { { char: " ", fg: "default", bg: "default", bold: false, italic: false, underline: false } }
          end
          cursor[:row] = rows - 1
        end
      end

      {
        size: { rows: rows, cols: cols },
        cursor: cursor,
        rows: grid,
        pending_dsr: pending_dsr,
      }
    end

    # Rebuild ANSI output from a state hash (for rendering/screenshot)
    def self.build_frame(state)
      rows = state.dig(:size, :rows) || state["size"]["rows"]
      cols = state.dig(:size, :cols) || state["size"]["cols"]
      grid = state[:rows] || state["rows"]
      cursor = state[:cursor] || state["cursor"]

      out = +""
      out << "\e[0m"
      out << "\e[2J\e[H"

      grid.each_with_index do |row, ri|
        row.each_with_index do |cell, ci|
          char = cell[:char] || cell["char"] || " "
          fg = cell[:fg] || cell["fg"] || "default"
          bg = cell[:bg] || cell["bg"] || "default"
          bold = cell[:bold] || cell["bold"] || false
          italic = cell[:italic] || cell["italic"] || false
          underline = cell[:underline] || cell["underline"] || false

          codes = []
          codes << "1" if bold
          codes << "3" if italic
          codes << "4" if underline

          fg_code = _color_code(fg, "38")
          bg_code = _color_code(bg, "48")

          codes << fg_code if fg_code
          codes << bg_code if bg_code

          out << "\e[#{codes.join(";")}m" unless codes.empty?
          out << char
        end
        out << "\n" if ri < rows - 1
      end

      out << "\e[0m"
      out
    end

    def self._apply_csi(seq, cursor, attrs, grid, rows, cols)
      # Strip leading escape char if present
      cleaned = seq.sub(/^\e/, "")
      match = cleaned.match(/^\[([\d;]*)([A-HJ-KP-SX@`fhmnR])$/)
      return unless match

      params = match[1].split(";").map(&:to_i)
      command = match[2]

      case command
      when "m"
        _apply_sgr(params, attrs)
      when "A" # CUU — Cursor Up
        n = params[0] || 1
        n = 1 if n == 0
        cursor[:row] = [cursor[:row] - n, 0].max
      when "B" # CUD — Cursor Down
        n = params[0] || 1
        n = 1 if n == 0
        cursor[:row] = [cursor[:row] + n, rows - 1].min
      when "C" # CUF — Cursor Forward
        n = params[0] || 1
        n = 1 if n == 0
        cursor[:col] = [cursor[:col] + n, cols - 1].min
      when "D" # CUB — Cursor Back
        n = params[0] || 1
        n = 1 if n == 0
        cursor[:col] = [cursor[:col] - n, 0].max
      when "H", "f" # CUP — Cursor Position
        r = (params[0] || 1) - 1
        c = (params[1] || 1) - 1
        cursor[:row] = r.clamp(0, rows - 1)
        cursor[:col] = c.clamp(0, cols - 1)
      when "J" # ED — Erase in Display
        case params[0]
        when nil, 0
          _erase_down(cursor, grid, rows, cols)
        when 1
          _erase_up(cursor, grid, cols)
        when 2, 3
          _erase_all(grid, rows, cols)
          cursor[:row] = 0
          cursor[:col] = 0
        end
      when "K" # EL — Erase in Line
        case params[0]
        when nil, 0
          _erase_line_right(cursor, grid, cols)
        when 1
          _erase_line_left(cursor, grid, cols)
        when 2
          _erase_line(cursor, grid, cols)
        end
      when "X" # Erase Characters
        n = params[0] || 1
        n.times do |i|
          next unless cursor[:row] < rows && cursor[:col] + i < cols
          grid[cursor[:row]][cursor[:col] + i][:char] = " "
        end
      when "n" # DSR — Device Status Report request
        # \e[6n = request cursor position → caller must respond with \e[row;colR
        return params[0] == 6
      when "R" # DSR response (from terminal side) or CPR — ignore
        nil
      end
    end

    def self._apply_sgr(params, attrs)
      return attrs.merge!(fg: "default", bg: "default", bold: false, italic: false, underline: false) if params.empty? || params == [0]

      i = 0
      while i < params.length
        p = params[i]
        case p
        when 0
          attrs.merge!(fg: "default", bg: "default", bold: false, italic: false, underline: false)
        when 1
          attrs[:bold] = true
        when 3
          attrs[:italic] = true
        when 4
          attrs[:underline] = true
        when 22
          attrs[:bold] = false
        when 23
          attrs[:italic] = false
        when 24
          attrs[:underline] = false
        when 7
          # Reverse — swap fg and bg
          attrs[:fg], attrs[:bg] = attrs[:bg], attrs[:fg]
        when 27
          attrs[:fg], attrs[:bg] = attrs[:bg], attrs[:fg]
        when 30..37
          attrs[:fg] = SGR_16_TO_NAME[p - 30] || "color#{p - 30}"
        when 38
          # Extended foreground
          if params[i + 1] == 5
            color = params[i + 2]
            attrs[:fg] = "color#{color}"
            i += 2
          elsif params[i + 1] == 2
            r, g, b = params[i + 2], params[i + 3], params[i + 4]
            attrs[:fg] = format("#%02x%02x%02x", r, g, b)
            i += 4
          end
        when 39
          attrs[:fg] = "default"
        when 40..47
          attrs[:bg] = SGR_16_TO_NAME[p - 40] || "bg_color#{p - 40}"
        when 48
          # Extended background
          if params[i + 1] == 5
            color = params[i + 2]
            attrs[:bg] = "color#{color}"
            i += 2
          elsif params[i + 1] == 2
            r, g, b = params[i + 2], params[i + 3], params[i + 4]
            attrs[:bg] = format("#%02x%02x%02x", r, g, b)
            i += 4
          end
        when 49
          attrs[:bg] = "default"
        when 90..97
          attrs[:fg] = "bright_#{SGR_16_TO_NAME[p - 90] || "color#{p - 90 + 8}"}"
        when 100..107
          attrs[:bg] = "bright_#{SGR_16_TO_NAME[p - 100] || "color#{p - 100 + 8}"}"
        end
        i += 1
      end
    end

    def self._erase_down(cursor, grid, rows, cols)
      r = cursor[:row]
      c = cursor[:col]

      # Erase from cursor to end of line
      (c...cols).each { |ci| grid[r][ci][:char] = " " if r < rows }

      # Erase remaining lines
      ((r + 1)...rows).each do |ri|
        cols.times { |ci| grid[ri][ci][:char] = " " }
      end
    end

    def self._erase_up(cursor, grid, cols)
      r = cursor[:row]
      c = cursor[:col]

      # Erase lines above cursor
      (0...r).each do |ri|
        cols.times { |ci| grid[ri][ci][:char] = " " }
      end

      # Erase from start of line to cursor
      (0..c).each { |ci| grid[r][ci][:char] = " " }
    end

    def self._erase_all(grid, rows, cols)
      rows.times do |ri|
        cols.times { |ci| grid[ri][ci][:char] = " " }
      end
    end

    def self._erase_line_right(cursor, grid, cols)
      r = cursor[:row]
      c = cursor[:col]
      (c...cols).each { |ci| grid[r][ci][:char] = " " if r < grid.length }
    end

    def self._erase_line_left(cursor, grid, cols)
      r = cursor[:row]
      c = cursor[:col]
      (0..c).each { |ci| grid[r][ci][:char] = " " if r < grid.length }
    end

    def self._erase_line(cursor, grid, cols)
      r = cursor[:row]
      cols.times { |ci| grid[r][ci][:char] = " " if r < grid.length }
    end

    def self._color_code(name, prefix)
      case name
      when "default" then nil
      when /^(bright_)?(.+)$/
        base_name = $2
        index = SGR_16_TO_NAME.key(base_name)
        index += 8 if $1 && index && index < 8
        index ? "#{prefix};5;#{index}" : nil
      when /^#([0-9a-fA-F]{6})$/
        r = $1[0..1].to_i(16)
        g = $1[2..3].to_i(16)
        b = $1[4..5].to_i(16)
        "#{prefix};2;#{r};#{g};#{b}"
      else
        nil
      end
    end
  end
end
