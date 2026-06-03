# frozen_string_literal: true

require "tans-parser"

module TUITD
  Selector = TansParser::Selector
  Element = TansParser::Element

  # Extend the aliased Selector with within scoping.
  # within is a testing-specific pattern (scope queries to a dialog region)
  # and therefore lives in tui-td rather than tans-parser.
  Selector.class_eval do
    # Return a new Selector whose elements are filtered to the given bounding box.
    # Coordinates of returned elements are relative to the box origin.
    def within(top_row, left_col, width, height)
      scoped = @elements.select do |e|
        e.row >= top_row && e.row < top_row + height &&
          e.col >= left_col && e.col < left_col + width
      end
      scoped.each do |e|
        e = e.dup
        e.row -= top_row
        e.col -= left_col
      end
      self.class.allocate.tap do |s|
        s.instance_variable_set(:@state, @state)
        s.instance_variable_set(:@elements, scoped)
      end
    end
  end
end
