# frozen_string_literal: true

module TUITD
  module CairoRenderer
    CELL_W = 8
    CELL_H = 16
    DEFAULT_FONT = "monospace"
    FONT_SIZE = 12.0

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

        surface = glyph_surface(char, bold: bold, italic: italic)
        composite(surface, cpn_image, px, py, fg_rgb)
      rescue StandardError => e
        warn "CairoRenderer: #{e.message}" if $DEBUG
      end

      private

      def glyph_surface(char, bold:, italic:)
        key = [char.ord, bold, italic]
        @cache[key] ||= render_surface(char, bold, italic)
      end

      def render_surface(char, bold, italic)
        surface = Cairo::ImageSurface.new(Cairo::Format::ARGB32, CELL_W, CELL_H)
        context = Cairo::Context.new(surface)

        slant = italic ? Cairo::FONT_SLANT_ITALIC : Cairo::FONT_SLANT_NORMAL
        weight = bold ? Cairo::FONT_WEIGHT_BOLD : Cairo::FONT_WEIGHT_NORMAL
        context.select_font_face(DEFAULT_FONT, slant, weight)
        context.set_font_size(FONT_SIZE)

        extents = context.text_extents(char)
        x_off = ((CELL_W - extents.width) / 2.0) - extents.x_bearing
        y_off = ((CELL_H - extents.height) / 2.0) - extents.y_bearing

        context.set_source_rgba(1.0, 1.0, 1.0, 1.0)
        context.move_to(x_off, y_off)
        context.show_text(char)

        surface
      end

      def composite(surface, cpn_image, px, py, fg_rgb)
        data = surface.data
        stride = surface.stride
        fr, fg, fb = fg_rgb

        CELL_H.times do |dy|
          row_offset = dy * stride
          CELL_W.times do |dx|
            pixel_offset = dx * 4
            a = data.getbyte(row_offset + pixel_offset + 3)
            next if a == 0

            coverage = a / 255.0

            existing = cpn_image[px + dx, py + dy]
            er = ChunkyPNG::Color.r(existing)
            eg = ChunkyPNG::Color.g(existing)
            eb = ChunkyPNG::Color.b(existing)

            nr = (fr * coverage + er * (1.0 - coverage)).round.clamp(0, 255)
            ng = (fg * coverage + eg * (1.0 - coverage)).round.clamp(0, 255)
            nb = (fb * coverage + eb * (1.0 - coverage)).round.clamp(0, 255)

            cpn_image[px + dx, py + dy] = ChunkyPNG::Color.rgb(nr, ng, nb)
          end
        end
      end
    end
  end
end
