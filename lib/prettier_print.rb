# frozen_string_literal: true
#
# This class implements a pretty printing algorithm. It finds line breaks and
# nice indentations for grouped structure.
#
# By default, the class assumes that primitive elements are strings and each
# byte in the strings is a single column in width. But it can be used for other
# situations by giving suitable arguments for some methods:
#
# * newline object and space generation block for PrettierPrint.new
# * optional width argument for PrettierPrint#text
# * PrettierPrint#breakable
#
# There are several candidate uses:
# * text formatting using proportional fonts
# * multibyte characters which has columns different to number of bytes
# * non-string formatting
#
# == Usage
#
# To use this module, you will need to generate a tree of print nodes that
# represent indentation and newline behavior before it gets sent to the printer.
# Each node has different semantics, depending on the desired output.
#
# The most basic node is a Text node. This represents plain text content that
# cannot be broken up even if it doesn't fit on one line. You would create one
# of those with the text method, as in:
#
#     PrettierPrint.format { |q| q.text('my content') }
#
# No matter what the desired output width is, the output for the snippet above
# will always be the same.
#
# If you want to allow the printer to break up the content on the space
# character when there isn't enough width for the full string on the same line,
# you can use the Breakable and Group nodes. For example:
#
#     PrettierPrint.format do |q|
#       q.group do
#         q.text("my")
#         q.breakable
#         q.text("content")
#       end
#     end
#
# Now, if everything fits on one line (depending on the maximum width specified)
# then it will be the same output as the first example. If, however, there is
# not enough room on the line, then you will get two lines of output, one for
# the first string and one for the second.
#
# There are other nodes for the print tree as well, described in the
# documentation below. They control alignment, indentation, conditional
# formatting, and more.
#
# == References
# Christian Lindig, Strictly Pretty, March 2000
# https://lindig.github.io/papers/strictly-pretty-2000.pdf
#
# Philip Wadler, A prettier printer, March 1998
# https://homepages.inf.ed.ac.uk/wadler/papers/prettier/prettier.pdf
#
class PrettierPrint
  # A node in the print tree that represents aligning nested nodes to a certain
  # prefix width or string.
  class Align
    attr_reader :indent, :contents

    def initialize(indent:, contents: [])
      @indent = indent
      @contents = contents
    end

    def pretty_print(q)
      q.group(2, "align#{indent}([", "])") do
        q.seplist(contents) { |content| q.pp(content) }
      end
    end
  end

  # A node in the print tree that represents a place in the buffer that the
  # content can be broken onto multiple lines.
  class Breakable
    attr_reader :separator, :width

    def initialize(
      separator = " ",
      width = separator.length,
      force: false,
      indent: true
    )
      @separator = separator
      @width = width
      @force = force
      @indent = indent
    end

    def force?
      @force
    end

    def indent?
      @indent
    end

    def pretty_print(q)
      q.text("breakable")

      attributes = [
        ("force=true" if force?),
        ("indent=false" unless indent?)
      ].compact

      if attributes.any?
        q.text("(")
        q.seplist(attributes, -> { q.text(", ") }) do |attribute|
          q.text(attribute)
        end
        q.text(")")
      end
    end
  end

  # Below here are the most common combination of options that are created when
  # creating new breakables. They are here to cut down on some allocations.
  BREAKABLE_SPACE = Breakable.new(" ", 1, indent: true, force: false).freeze
  BREAKABLE_EMPTY = Breakable.new("", 0, indent: true, force: false).freeze
  BREAKABLE_FORCE = Breakable.new(" ", 1, indent: true, force: true).freeze
  BREAKABLE_RETURN = Breakable.new(" ", 1, indent: false, force: true).freeze

  # A node in the print tree that forces the surrounding group to print out in
  # the "break" mode as opposed to the "flat" mode. Useful for when you need to
  # force a newline into a group.
  class BreakParent
    def pretty_print(q)
      q.text("break-parent")
    end
  end

  # Since there's really no difference in these instances, just using the same
  # one saves on some allocations.
  BREAK_PARENT = BreakParent.new.freeze

  # A node in the print tree that represents a group of items which the printer
  # should try to fit onto one line. This is the basic command to tell the
  # printer when to break. Groups are usually nested, and the printer will try
  # to fit everything on one line, but if it doesn't fit it will break the
  # outermost group first and try again. It will continue breaking groups until
  # everything fits (or there are no more groups to break).
  class Group
    attr_reader :depth, :contents

    def initialize(depth, contents: [])
      @depth = depth
      @contents = contents
      @break = false
    end

    def break
      @break = true
    end

    def break?
      @break
    end

    def pretty_print(q)
      q.group(2, break? ? "breakGroup([" : "group([", "])") do
        q.seplist(contents) { |content| q.pp(content) }
      end
    end
  end

  # A node in the print tree that represents printing one thing if the
  # surrounding group node is broken and another thing if the surrounding group
  # node is flat.
  class IfBreak
    attr_reader :break_contents, :flat_contents

    def initialize(break_contents: [], flat_contents: [])
      @break_contents = break_contents
      @flat_contents = flat_contents
    end

    def pretty_print(q)
      q.group(2, "if-break(", ")") do
        q.breakable("")
        q.group(2, "[", "],") do
          q.seplist(break_contents) { |content| q.pp(content) }
        end
        q.breakable
        q.group(2, "[", "]") do
          q.seplist(flat_contents) { |content| q.pp(content) }
        end
      end
    end
  end

  # A node in the print tree that is a variant of the Align node that indents
  # its contents by one level.
  class Indent
    attr_reader :contents

    def initialize(contents: [])
      @contents = contents
    end

    def pretty_print(q)
      q.group(2, "indent([", "])") do
        q.seplist(contents) { |content| q.pp(content) }
      end
    end
  end

  # A node in the print tree that has its own special buffer for implementing
  # content that should flush before any newline.
  #
  # Useful for implementating trailing content, as it's not always practical to
  # constantly check where the line ends to avoid accidentally printing some
  # content after a line suffix node.
  class LineSuffix
    DEFAULT_PRIORITY = 1

    attr_reader :priority, :contents

    def initialize(priority: DEFAULT_PRIORITY, contents: [])
      @priority = priority
      @contents = contents
    end

    def pretty_print(q)
      q.group(2, "line-suffix([", "])") do
        q.seplist(contents) { |content| q.pp(content) }
      end
    end
  end

  # A node in the print tree that represents plain content that cannot be broken
  # up (by default this assumes strings, but it can really be anything).
  class Text
    attr_reader :objects, :width

    def initialize
      @objects = []
      @width = 0
    end

    def add(object: "", width: object.length)
      @objects << object
      @width += width
    end

    def pretty_print(q)
      q.group(2, "text([", "])") do
        q.seplist(objects) { |object| q.pp(object) }
      end
    end
  end

  # A node in the print tree that represents trimming all of the indentation of
  # the current line, in the rare case that you need to ignore the indentation
  # that you've already created. This node should be placed after a Breakable.
  class Trim
    def pretty_print(q)
      q.text("trim")
    end
  end

  # Since all of the instances here are the same, we can reuse the same one to
  # cut down on allocations.
  TRIM = Trim.new.freeze

  # When building up the contents in the output buffer, it's convenient to be
  # able to trim trailing whitespace before newlines. If the output object is a
  # string or array or strings, then we can do this with some gsub calls. If
  # not, then this effectively just wraps the output object and forwards on
  # calls to <<.
  module Buffer
    # This is an output buffer that wraps a string output object. It provides a
    # trim! method that trims off trailing whitespace from the string using
    # gsub!.
    class StringBuffer
      attr_reader :output

      def initialize(output = "".dup)
        @output = output
      end

      def <<(object)
        @output << object
      end

      def trim!
        length = output.length
        output.gsub!(/[\t ]*\z/, "")
        length - output.length
      end
    end

    # This is an output buffer that wraps an array output object. It provides a
    # trim! method that trims off trailing whitespace from the last element in
    # the array if it's an unfrozen string using the same method as the
    # StringBuffer.
    class ArrayBuffer
      attr_reader :output

      def initialize(output = [])
        @output = output
      end

      def <<(object)
        @output << object
      end

      def trim!
        return 0 if output.empty?

        trimmed = 0

        while output.any? && output.last.is_a?(String) &&
                output.last.match?(/\A[\t ]*\z/)
          trimmed += output.pop.length
        end

        if output.any? && output.last.is_a?(String) && !output.last.frozen?
          length = output.last.length
          output.last.gsub!(/[\t ]*\z/, "")
          trimmed += length - output.last.length
        end

        trimmed
      end
    end

    # This is a switch for building the correct output buffer wrapper class for
    # the given output object.
    def self.for(output)
      output.is_a?(String) ? StringBuffer.new(output) : ArrayBuffer.new(output)
    end
  end

  # When printing, you can optionally specify the value that should be used
  # whenever a group needs to be broken onto multiple lines. In this case the
  # default is \n.
  DEFAULT_NEWLINE = "\n"

  # When generating spaces after a newline for indentation, by default we
  # generate one space per character needed for indentation. You can change this
  # behavior (for instance to use tabs) by passing a different genspace
  # procedure.
  DEFAULT_GENSPACE = ->(n) { " " * n }
  Ractor.make_shareable(DEFAULT_GENSPACE) if defined?(Ractor)

  # There are two modes in printing, break and flat. When we're in break mode,
  # any lines will use their newline, any if-breaks will use their break
  # contents, etc.
  MODE_BREAK = 1

  # This is another print mode much like MODE_BREAK. When we're in flat mode, we
  # attempt to print everything on one line until we either hit a broken group,
  # a forced line, or the maximum width.
  MODE_FLAT = 2

  # The default indentation for printing is zero, assuming that the code starts
  # at the top level. That can be changed if desired to start from a different
  # indentation level.
  DEFAULT_INDENTATION = 0

  # This is a convenience method which is same as follows:
  #
  #   begin
  #     q = PrettierPrint.new(output, maxwidth, newline, &genspace)
  #     ...
  #     q.flush
  #     output
  #   end
  #
  def self.format(
    output = "".dup,
    maxwidth = 80,
    newline = DEFAULT_NEWLINE,
    genspace = DEFAULT_GENSPACE,
    indentation = DEFAULT_INDENTATION
  )
    q = new(output, maxwidth, newline, &genspace)
    yield q
    q.flush(indentation)
    output
  end

  # The output object. It represents the final destination of the contents of
  # the print tree. It should respond to <<.
  #
  # This defaults to "".dup
  attr_reader :output

  # This is an output buffer that wraps the output object and provides
  # additional functionality depending on its type.
  #
  # This defaults to Buffer::StringBuffer.new("".dup)
  attr_reader :buffer

  # The maximum width of a line, before it is separated in to a newline
  #
  # This defaults to 80, and should be an Integer
  attr_reader :maxwidth

  # The value that is appended to +output+ to add a new line.
  #
  # This defaults to "\n", and should be String
  attr_reader :newline

  # An object that responds to call that takes one argument, of an Integer, and
  # returns the corresponding number of spaces.
  #
  # By default this is: ->(n) { ' ' * n }
  attr_reader :genspace

  # The stack of groups that are being printed.
  attr_reader :groups

  # The current array of contents that calls to methods that generate print tree
  # nodes will append to.
  attr_reader :target

  # Creates a buffer for pretty printing.
  #
  # +output+ is an output target. If it is not specified, '' is assumed. It
  # should have a << method which accepts the first argument +obj+ of
  # PrettierPrint#text, the first argument +separator+ of PrettierPrint#breakable,
  # the first argument +newline+ of PrettierPrint.new, and the result of a given
  # block for PrettierPrint.new.
  #
  # +maxwidth+ specifies maximum line length. If it is not specified, 80 is
  # assumed. However actual outputs may overflow +maxwidth+ if long
  # non-breakable texts are provided.
  #
  # +newline+ is used for line breaks. "\n" is used if it is not specified.
  #
  # The block is used to generate spaces. ->(n) { ' ' * n } is used if it is not
  # given.
  def initialize(
    output = "".dup,
    maxwidth = 80,
    newline = DEFAULT_NEWLINE,
    &genspace
  )
    @output = output
    @buffer = Buffer.for(output)
    @maxwidth = maxwidth
    @newline = newline
    @genspace = genspace || DEFAULT_GENSPACE
    reset
  end

  # Returns the group most recently added to the stack.
  #
  # Contrived example:
  #   out = ""
  #   => ""
  #   q = PrettierPrint.new(out)
  #   => #<PrettierPrint:0x0>
  #   q.group {
  #     q.text q.current_group.inspect
  #     q.text q.newline
  #     q.group(q.current_group.depth + 1) {
  #       q.text q.current_group.inspect
  #       q.text q.newline
  #       q.group(q.current_group.depth + 1) {
  #         q.text q.current_group.inspect
  #         q.text q.newline
  #         q.group(q.current_group.depth + 1) {
  #           q.text q.current_group.inspect
  #           q.text q.newline
  #         }
  #       }
  #     }
  #   }
  #   => 284
  #    puts out
  #   #<PrettierPrint::Group:0x0 @depth=1>
  #   #<PrettierPrint::Group:0x0 @depth=2>
  #   #<PrettierPrint::Group:0x0 @depth=3>
  #   #<PrettierPrint::Group:0x0 @depth=4>
  def current_group
    groups.last
  end

  # Flushes all of the generated print tree onto the output buffer, then clears
  # the generated tree from memory.
  def flush(base_indentation = DEFAULT_INDENTATION)
    # First, get the root group, since we placed one at the top to begin with.
    doc = groups.first

    # This represents how far along the current line we are. It gets reset
    # back to 0 when we encounter a newline.
    position = base_indentation

    # Start the buffer with the base indentation level.
    buffer << genspace.call(base_indentation) if base_indentation > 0

    # This is our command stack. A command consists of a triplet of an
    # indentation level, the mode (break or flat), and a doc node.
    commands = [[base_indentation, MODE_BREAK, doc]]

    # This is a small optimization boolean. It keeps track of whether or not
    # when we hit a group node we should check if it fits on the same line.
    should_remeasure = false

    # This is a separate command stack that includes the same kind of triplets
    # as the commands variable. It is used to keep track of things that should
    # go at the end of printed lines once the other doc nodes are accounted for.
    # Typically this is used to implement comments.
    line_suffixes = []

    # This is a special sort used to order the line suffixes by both the
    # priority set on the line suffix and the index it was in the original
    # array.
    line_suffix_sort = ->(line_suffix) do
      [-line_suffix.last.priority, -line_suffixes.index(line_suffix)]
    end

    # This is a linear stack instead of a mutually recursive call defined on
    # the individual doc nodes for efficiency.
    while (indent, mode, doc = commands.pop)
      case doc
      when String
        buffer << doc
        position += doc.length
      when Group
        if mode == MODE_FLAT && !should_remeasure
          next_mode = doc.break? ? MODE_BREAK : MODE_FLAT
          commands += doc.contents.reverse.map { |part| [indent, next_mode, part] }
        else
          should_remeasure = false

          if doc.break?
            commands += doc.contents.reverse.map { |part| [indent, MODE_BREAK, part] }
          else
            next_commands = doc.contents.reverse.map { |part| [indent, MODE_FLAT, part] }

            if fits?(next_commands, commands, maxwidth - position)
              commands += next_commands
            else
              commands += next_commands.map { |command| command[1] = MODE_BREAK; command }
            end
          end
        end
      when Breakable
        if mode == MODE_FLAT
          if doc.force?
            # This line was forced into the output even if we were in flat mode,
            # so we need to tell the next group that no matter what, it needs to
            # remeasure because the previous measurement didn't accurately
            # capture the entire expression (this is necessary for nested
            # groups).
            should_remeasure = true
          else
            buffer << doc.separator
            position += doc.width
            next
          end
        end

        # If there are any commands in the line suffix buffer, then we're going
        # to flush them now, as we are about to add a newline.
        if line_suffixes.any?
          commands << [indent, mode, doc]

          line_suffixes.sort_by(&line_suffix_sort).each do |(indent, mode, doc)|
            commands += doc.contents.reverse.map { |part| [indent, mode, part] }
          end

          line_suffixes.clear
          next
        end

        if !doc.indent?
          buffer << newline
          position = 0
        else
          position -= buffer.trim!
          buffer << newline
          buffer << genspace.call(indent)
          position = indent
        end
      when Indent
        next_indent = indent + 2
        commands += doc.contents.reverse.map { |part| [next_indent, mode, part] }
      when Align
        next_indent = indent + doc.indent
        commands += doc.contents.reverse.map { |part| [next_indent, mode, part] }
      when Trim
        position -= buffer.trim!
      when IfBreak
        if mode == MODE_BREAK && doc.break_contents.any?
          commands += doc.break_contents.reverse.map { |part| [indent, mode, part] }
        elsif mode == MODE_FLAT && doc.flat_contents.any?
          commands += doc.flat_contents.reverse.map { |part| [indent, mode, part] }
        end
      when LineSuffix
        line_suffixes << [indent, mode, doc]
      when BreakParent
        # do nothing
      when Text
        doc.objects.each { |object| buffer << object }
        position += doc.width
      else
        # Special case where the user has defined some way to get an extra doc
        # node that we don't explicitly support into the list. In this case
        # we're going to assume it's 0-width and just append it to the output
        # buffer.
        #
        # This is useful behavior for putting marker nodes into the list so that
        # you can know how things are getting mapped before they get printed.
        buffer << doc
      end

      if commands.empty? && line_suffixes.any?
        line_suffixes.sort_by(&line_suffix_sort).each do |(indent, mode, doc)|
          commands += doc.contents.reverse.map { |part| [indent, mode, part] }
        end

        line_suffixes.clear
      end
    end

    # Reset the group stack and target array so that this pretty printer object
    # can continue to be used before calling flush again if desired.
    reset
  end

  # ----------------------------------------------------------------------------
  # Helper node builders
  # ----------------------------------------------------------------------------

  # The vast majority of breakable calls you receive while formatting are a
  # space in flat mode and a newline in break mode. Since this is so common,
  # we have a method here to skip past unnecessary calculation.
  def breakable_space
    target << BREAKABLE_SPACE
  end

  # Another very common breakable call you receive while formatting is an
  # empty string in flat mode and a newline in break mode. Similar to
  # breakable_space, this is here for avoid unnecessary calculation.
  def breakable_empty
    target << BREAKABLE_EMPTY
  end

  # The final of the very common breakable calls you receive while formatting
  # is the normal breakable space but with the addition of the break_parent.
  def breakable_force
    target << BREAKABLE_FORCE
    break_parent
  end

  # This is the same shortcut as breakable_force, except that it doesn't indent
  # the next line. This is necessary if you're trying to preserve some custom
  # formatting like a multi-line string.
  def breakable_return
    target << BREAKABLE_RETURN
    break_parent
  end

  # A convenience method which is same as follows:
  #
  #   text(",")
  #   breakable
  def comma_breakable
    text(",")
    breakable_space
  end

  # This is similar to #breakable except the decision to break or not is
  # determined individually.
  #
  # Two #fill_breakable under a group may cause 4 results:
  # (break,break), (break,non-break), (non-break,break), (non-break,non-break).
  # This is different to #breakable because two #breakable under a group
  # may cause 2 results: (break,break), (non-break,non-break).
  #
  # The text +separator+ is inserted if a line is not broken at this point.
  #
  # If +separator+ is not specified, ' ' is used.
  #
  # If +width+ is not specified, +separator.length+ is used. You will have to
  # specify this when +separator+ is a multibyte character, for example.
  def fill_breakable(separator = " ", width = separator.length)
    group { breakable(separator, width) }
  end

  # This method calculates the position of the text relative to the current
  # indentation level when the doc has been printed. It's useful for
  # determining how to align text to doc nodes that are already built into the
  # tree.
  def last_position(node)
    queue = [node]
    width = 0

    while (doc = queue.shift)
      case doc
      when String
        width += doc.length
      when Group, Indent, Align
        queue = doc.contents + queue
      when Breakable
        width = 0
      when IfBreak
        queue = doc.break_contents + queue
      when Text
        width += doc.width
      end
    end

    width
  end

  # This method will remove any breakables from the list of contents so that
  # no newlines are present in the output. If a newline is being forced into
  # the output, the replace value will be used.
  def remove_breaks(node, replace = "; ")
    queue = [node]

    while (doc = queue.shift)
      case doc
      when Align, Indent, Group
        doc.contents.map! { |child| remove_breaks_with(child, replace) }
        queue += doc.contents
      when IfBreak
        doc.flat_contents.map! { |child| remove_breaks_with(child, replace) }
        queue += doc.flat_contents
      end
    end
  end

  # Adds a separated list.
  # The list is separated by comma with breakable space, by default.
  #
  # #seplist iterates the +list+ using +iter_method+.
  # It yields each object to the block given for #seplist.
  # The procedure +separator_proc+ is called between each yields.
  #
  # If the iteration is zero times, +separator_proc+ is not called at all.
  #
  # If +separator_proc+ is nil or not given,
  # +lambda { comma_breakable }+ is used.
  # If +iter_method+ is not given, :each is used.
  #
  # For example, following 3 code fragments has similar effect.
  #
  #   q.seplist([1,2,3]) {|v| xxx v }
  #
  #   q.seplist([1,2,3], lambda { q.comma_breakable }, :each) {|v| xxx v }
  #
  #   xxx 1
  #   q.comma_breakable
  #   xxx 2
  #   q.comma_breakable
  #   xxx 3
  def seplist(list, sep=nil, iter_method=:each) # :yield: element
    first = true
    list.__send__(iter_method) {|*v|
      if first
        first = false
      elsif sep
        sep.call
      else
        comma_breakable
      end
      RUBY_VERSION >= "3.0" ? yield(*v, **{}) : yield(*v)
    }
  end

  # ----------------------------------------------------------------------------
  # Markers node builders
  # ----------------------------------------------------------------------------

  # This says "you can break a line here if necessary", and a +width+\-column
  # text +separator+ is inserted if a line is not broken at the point.
  #
  # If +separator+ is not specified, ' ' is used.
  #
  # If +width+ is not specified, +separator.length+ is used. You will have to
  # specify this when +separator+ is a multibyte character, for example.
  #
  # By default, if the surrounding group is broken and a newline is inserted,
  # the printer will indent the subsequent line up to the current level of
  # indentation. You can disable this behavior with the +indent+ argument if
  # that's not desired (rare).
  #
  # By default, when you insert a Breakable into the print tree, it only breaks
  # the surrounding group when the group's contents cannot fit onto the
  # remaining space of the current line. You can force it to break the
  # surrounding group instead if you always want the newline with the +force+
  # argument.
  #
  # There are a few circumstances where you'll want to force the newline into
  # the output but no insert a break parent (because you don't want to
  # necessarily force the groups to break unless they need to). In this case you
  # can pass `force: :skip_break_parent` to this method and it will not insert
  # a break parent.`
  def breakable(
    separator = " ",
    width = separator.length,
    indent: true,
    force: false
  )
    target << Breakable.new(separator, width, indent: indent, force: !!force)
    break_parent if force == true
  end

  # This inserts a BreakParent node into the print tree which forces the
  # surrounding and all parent group nodes to break.
  def break_parent
    doc = BREAK_PARENT
    target << doc

    groups.reverse_each do |group|
      break if group.break?
      group.break
    end
  end

  # This inserts a Trim node into the print tree which, when printed, will clear
  # all whitespace at the end of the output buffer. This is useful for the rare
  # case where you need to delete printed indentation and force the next node
  # to start at the beginning of the line.
  def trim
    target << TRIM
  end

  # ----------------------------------------------------------------------------
  # Container node builders
  # ----------------------------------------------------------------------------

  # Groups line break hints added in the block. The line break hints are all to
  # be used or not.
  #
  # If +indent+ is specified, the method call is regarded as nested by
  # nest(indent) { ... }.
  #
  # If +open_object+ is specified, <tt>text(open_object, open_width)</tt> is
  # called before grouping. If +close_object+ is specified,
  # <tt>text(close_object, close_width)</tt> is called after grouping.
  def group(
    indent = 0,
    open_object = "",
    close_object = "",
    open_width = open_object.length,
    close_width = close_object.length
  )
    text(open_object, open_width) if open_object != ""

    doc = Group.new(groups.last.depth + 1)
    groups << doc
    target << doc

    with_target(doc.contents) do
      if indent != 0
        nest(indent) { yield }
      else
        yield
      end
    end

    groups.pop
    text(close_object, close_width) if close_object != ""

    doc
  end

  # A small DSL-like object used for specifying the alternative contents to be
  # printed if the surrounding group doesn't break for an IfBreak node.
  class IfBreakBuilder
    attr_reader :q, :flat_contents

    def initialize(q, flat_contents)
      @q = q
      @flat_contents = flat_contents
    end

    def if_flat
      q.with_target(flat_contents) { yield }
    end
  end

  # When we already know that groups are broken, we don't actually need to track
  # the flat versions of the contents. So this builder version is effectively a
  # no-op, but we need it to maintain the same API. The only thing this can
  # impact is that if there's a forced break in the flat contents, then we need
  # to propagate that break up the whole tree.
  class IfFlatIgnore
    attr_reader :q

    def initialize(q)
      @q = q
    end

    def if_flat
      contents = []
      group = Group.new(0, contents: contents)

      q.with_target(contents) { yield }
      q.break_parent if group.break?
    end
  end

  # Inserts an IfBreak node with the contents of the block being added to its
  # list of nodes that should be printed if the surrounding node breaks. If it
  # doesn't, then you can specify the contents to be printed with the #if_flat
  # method used on the return object from this method. For example,
  #
  #     q.if_break { q.text('do') }.if_flat { q.text('{') }
  #
  # In the example above, if the surrounding group is broken it will print 'do'
  # and if it is not it will print '{'.
  def if_break
    break_contents = []
    flat_contents = []

    doc = IfBreak.new(break_contents: break_contents, flat_contents: flat_contents)
    target << doc

    with_target(break_contents) { yield }

    if groups.last.break?
      IfFlatIgnore.new(self)
    else
      IfBreakBuilder.new(self, flat_contents)
    end
  end

  # This is similar to if_break in that it also inserts an IfBreak node into the
  # print tree, however it's starting from the flat contents, and cannot be used
  # to build the break contents.
  def if_flat
    if groups.last.break?
      contents = []
      group = Group.new(0, contents: contents)

      with_target(contents) { yield }
      break_parent if group.break?
    else
      flat_contents = []
      doc = IfBreak.new(break_contents: [], flat_contents: flat_contents)
      target << doc

      with_target(flat_contents) { yield }
      doc
    end
  end

  # Very similar to the #nest method, this indents the nested content by one
  # level by inserting an Indent node into the print tree. The contents of the
  # node are determined by the block.
  def indent
    contents = []
    doc = Indent.new(contents: contents)
    target << doc

    with_target(contents) { yield }
    doc
  end

  # Inserts a LineSuffix node into the print tree. The contents of the node are
  # determined by the block.
  def line_suffix(priority: LineSuffix::DEFAULT_PRIORITY)
    doc = LineSuffix.new(priority: priority)
    target << doc

    with_target(doc.contents) { yield }
    doc
  end

  # Increases left margin after newline with +indent+ for line breaks added in
  # the block.
  def nest(indent)
    contents = []
    doc = Align.new(indent: indent, contents: contents)
    target << doc

    with_target(contents) { yield }
    doc
  end

  # This adds +object+ as a text of +width+ columns in width.
  #
  # If +width+ is not specified, object.length is used.
  def text(object = "", width = object.length)
    doc = target.last

    unless doc.is_a?(Text)
      doc = Text.new
      target << doc
    end

    doc.add(object: object, width: width)
    doc
  end

  # ----------------------------------------------------------------------------
  # Internal APIs
  # ----------------------------------------------------------------------------

  # A convenience method used by a lot of the print tree node builders that
  # temporarily changes the target that the builders will append to.
  def with_target(target)
    previous_target, @target = @target, target
    yield
    @target = previous_target
  end

  private

  # This method returns a boolean as to whether or not the remaining commands
  # fit onto the remaining space on the current line. If we finish printing
  # all of the commands or if we hit a newline, then we return true. Otherwise
  # if we continue printing past the remaining space, we return false.
  def fits?(next_commands, rest_commands, remaining)
    # This is the index in the remaining commands that we've handled so far.
    # We reverse through the commands and add them to the stack if we've run
    # out of nodes to handle.
    rest_index = rest_commands.length

    # This is our stack of commands, very similar to the commands list in the
    # print method.
    commands = [*next_commands]

    # This is our output buffer, really only necessary to keep track of
    # because we could encounter a Trim doc node that would actually add
    # remaining space.
    fit_buffer = buffer.class.new

    while remaining >= 0
      if commands.empty?
        return true if rest_index == 0

        rest_index -= 1
        commands << rest_commands[rest_index]
        next
      end

      indent, mode, doc = commands.pop

      case doc
      when String
        fit_buffer << doc
        remaining -= doc.length
      when Group
        next_mode = doc.break? ? MODE_BREAK : mode
        commands += doc.contents.reverse.map { |part| [indent, next_mode, part] }
      when Breakable
        if mode == MODE_FLAT && !doc.force?
          fit_buffer << doc.separator
          remaining -= doc.width
          next
        end

        return true
      when Indent
        next_indent = indent + 2
        commands += doc.contents.reverse.map { |part| [next_indent, mode, part] }
      when Align
        next_indent = indent + doc.indent
        commands += doc.contents.reverse.map { |part| [next_indent, mode, part] }
      when Trim
        remaining += fit_buffer.trim!
      when IfBreak
        if mode == MODE_BREAK && doc.break_contents.any?
          commands += doc.break_contents.reverse.map { |part| [indent, mode, part] }
        elsif mode == MODE_FLAT && doc.flat_contents.any?
          commands += doc.flat_contents.reverse.map { |part| [indent, mode, part] }
        end
      when Text
        doc.objects.each { |object| fit_buffer << object }
        remaining -= doc.width
      end
    end

    false
  end

  # Resets the group stack and target array so that this pretty printer object
  # can continue to be used before calling flush again if desired.
  def reset
    contents = []
    @groups = [Group.new(0, contents: contents)]
    @target = contents
  end

  def remove_breaks_with(doc, replace)
    case doc
    when Breakable
      text = Text.new
      text.add(object: doc.force? ? replace : doc.separator, width: doc.width)
      text
    when IfBreak
      Align.new(indent: 0, contents: doc.flat_contents)
    else
      doc
    end
  end
end

require_relative "prettier_print/single_line"
