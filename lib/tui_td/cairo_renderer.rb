# frozen_string_literal: true

module TUITD
  module CairoRenderer
    CELL_W = 8
    CELL_H = 16
    DEFAULT_FONT = "Arial Unicode MS"
    FONT_SIZE = 12.0
    RENDER_SCALE = 3

    @available = false
    @cache = {}

    begin
      require "cairo"
      @available = true
    rescue LoadError
      # Cairo not available; render_glyph_onto is a no-op
    end

    class << self
      def available?
        @available
      end

      def render_glyph_onto(cpn_image, px, py, char, fg_rgb, bold:, italic:)
        return unless available?

        alpha = glyph_alpha(char, bold: bold, italic: italic)
        composite(alpha, cpn_image, px, py, fg_rgb)
      rescue StandardError => e
        warn "CairoRenderer: #{e.message}" if $DEBUG
      end

      private

      def glyph_alpha(char, bold:, italic:)
        key = [char.ord, bold, italic]
        @cache[key] ||= render_surface(char, bold, italic)
      end

      def render_surface(char, bold, italic)
        # Render at higher resolution then box-filter downsample for smoother edges
        scale = RENDER_SCALE
        big_w = CELL_W * scale
        big_h = CELL_H * scale
        surface = Cairo::ImageSurface.new(Cairo::Format::ARGB32, big_w, big_h)
        context = Cairo::Context.new(surface)

        context.antialias = Cairo::ANTIALIAS_NONE

        fo = Cairo::FontOptions.new
        fo.hint_style = Cairo::HINT_STYLE_FULL
        fo.hint_metrics = Cairo::HINT_METRICS_ON
        context.font_options = fo

        slant = italic ? Cairo::FONT_SLANT_ITALIC : Cairo::FONT_SLANT_NORMAL
        weight = bold ? Cairo::FONT_WEIGHT_BOLD : Cairo::FONT_WEIGHT_NORMAL
        context.select_font_face(DEFAULT_FONT, slant, weight)
        context.set_font_size(FONT_SIZE * scale)

        extents = context.text_extents(char)
        x_off = ((big_w - extents.width) / 2.0) - extents.x_bearing
        y_off = ((big_h - extents.height) / 2.0) - extents.y_bearing

        context.set_source_rgba(1.0, 1.0, 1.0, 1.0)
        context.move_to(x_off, y_off)
        context.show_text(char)

        data = surface.data
        stride = surface.stride
        scale_sq = scale * scale

        alpha_grid = Array.new(CELL_H) { Array.new(CELL_W, 0) }
        CELL_H.times do |dy|
          CELL_W.times do |dx|
            sum = 0
            scale.times do |sy|
              row_off = (dy * scale + sy) * stride
              scale.times do |sx|
                sum += data.getbyte(row_off + (dx * scale + sx) * 4 + 3)
              end
            end
            alpha_grid[dy][dx] = sum / scale_sq
          end
        end

        alpha_grid
      end

      def composite(alpha_grid, cpn_image, px, py, fg_rgb)
        fr, fg, fb = fg_rgb

        CELL_H.times do |dy|
          CELL_W.times do |dx|
            a = alpha_grid[dy][dx]
            next if a < 24

            factor = [a, 255].min / 255.0
            r = (fr * factor).to_i
            g = (fg * factor).to_i
            b = (fb * factor).to_i
            cpn_image[px + dx, py + dy] = ChunkyPNG::Color.rgb(r, g, b)
          end
        end
      end
    end
  end
end
