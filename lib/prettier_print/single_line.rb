# frozen_string_literal: true

class PrettierPrint
  # PrettierPrint::SingleLine is used by PrettierPrint.singleline_format
  #
  # It is passed to be similar to a PrettierPrint object itself, by responding to
  # all of the same print tree node builder methods, as well as the #flush
  # method.
  #
  # The significant difference here is that there are no line breaks in the
  # output. If an IfBreak node is used, only the flat contents are printed.
  # LineSuffix nodes are printed at the end of the buffer when #flush is called.
  class SingleLine
    # The output object. It stores rendered text and should respond to <<.
    attr_reader :output

    # The current array of contents that the print tree builder methods should
    # append to.
    attr_reader :target

    # A buffer output that wraps any calls to line_suffix that will be flushed
    # at the end of printing.
    attr_reader :line_suffixes

    # Create a PrettierPrint::SingleLine object
    #
    # Arguments:
    # * +output+ - String (or similar) to store rendered text. Needs to respond
    #              to '<<'.
    # * +maxwidth+ - Argument position expected to be here for compatibility.
    #                This argument is a noop.
    # * +newline+ - Argument position expected to be here for compatibility.
    #               This argument is a noop.
    def initialize(output, _maxwidth = nil, _newline = nil)
      @output = Buffer.for(output)
      @target = @output
      @line_suffixes = Buffer::ArrayBuffer.new
    end

    # Flushes the line suffixes onto the output buffer.
    def flush
      line_suffixes.output.each { |doc| output << doc }
    end

    # --------------------------------------------------------------------------
    # Markers node builders
    # --------------------------------------------------------------------------

    # Appends +separator+ to the text to be output. By default +separator+ is
    # ' '
    #
    # The +width+, +indent+, and +force+ arguments are here for compatibility.
    # They are all noop arguments.
    def breakable(
      separator = " ",
      _width = separator.length,
      indent: nil,
      force: nil
    )
      target << separator
    end

    # Here for compatibility, does nothing.
    def break_parent
    end

    # Appends +separator+ to the output buffer. +width+ is a noop here for
    # compatibility.
    def fill_breakable(separator = " ", _width = separator.length)
      target << separator
    end

    # Immediately trims the output buffer.
    def trim
      target.trim!
    end

    # --------------------------------------------------------------------------
    # Container node builders
    # --------------------------------------------------------------------------

    # Opens a block for grouping objects to be pretty printed.
    #
    # Arguments:
    # * +indent+ - noop argument. Present for compatibility.
    # * +open_obj+ - text appended before the &block. Default is ''
    # * +close_obj+ - text appended after the &block. Default is ''
    # * +open_width+ - noop argument. Present for compatibility.
    # * +close_width+ - noop argument. Present for compatibility.
    def group(
      _indent = nil,
      open_object = "",
      close_object = "",
      _open_width = nil,
      _close_width = nil
    )
      target << open_object
      yield
      target << close_object
    end

    # A class that wraps the ability to call #if_flat. The contents of the
    # #if_flat block are executed immediately, so effectively this class and the
    # #if_break method that triggers it are unnecessary, but they're here to
    # maintain compatibility.
    class IfBreakBuilder
      def if_flat
        yield
      end
    end

    # Effectively unnecessary, but here for compatibility.
    def if_break
      IfBreakBuilder.new
    end

    # Also effectively unnecessary, but here for compatibility.
    def if_flat
    end

    # A noop that immediately yields.
    def indent
      yield
    end

    # Changes the target output buffer to the line suffix output buffer which
    # will get flushed at the end of printing.
    def line_suffix
      previous_target, @target = @target, line_suffixes
      yield
      @target = previous_target
    end

    # Takes +indent+ arg, but does nothing with it.
    #
    # Yields to a block.
    def nest(_indent)
      yield
    end

    # Add +object+ to the text to be output.
    #
    # +width+ argument is here for compatibility. It is a noop argument.
    def text(object = "", _width = nil)
      target << object
    end
  end

  # This is similar to PrettierPrint::format but the result has no breaks.
  #
  # +maxwidth+, +newline+ and +genspace+ are ignored.
  #
  # The invocation of +breakable+ in the block doesn't break a line and is
  # treated as just an invocation of +text+.
  #
  def self.singleline_format(
    output = +"",
    _maxwidth = nil,
    _newline = nil,
    _genspace = nil
  )
    q = SingleLine.new(output)
    yield q
    output
  end
end
