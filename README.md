# PrettierPrint

[![Build Status](https://github.com/ruby-syntax-tree/prettier_print/workflows/Main/badge.svg)](https://github.com/ruby-syntax-tree/prettier_print/actions)
[![Gem Version](https://img.shields.io/gem/v/prettier_print.svg)](https://rubygems.org/gems/prettier_print)

A drop-in replacement for the `prettyprint` gem with more functionality.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "prettier_print"
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install prettier_print

## Usage

To use `PrettierPrint`, you're going to construct a tree that encodes information about how to best print your data, then give the tree a maximum width within which to print. The tree will contain various nodes like `Text` (which wraps actual content to be printed), `Breakable` (a place where a line break could be inserted), `Group` (a set of nodes that the printer should attempt to print on one line), and others.

### Building the printer

To construct the tree, you're going to instantiate a `PrettierPrint` object, like so:

```ruby
q = PrettierPrint.new(+"", 80, "\n") { |n| " " * n }
```

By convention, the `PrettierPrint` object is called `q`. The arguments are detailed below.

* This first argument (and the only required argument) is the output object. It can be anything that responds to `<<`, provided that method accepts strings. Usually this is an unfrozen empty string (`+""`). It's also common to see an empty array (`[]`).
* The optional second argument is the print width. This defaults to `80`. For more information about this see the section below on [print width](#print-width).
* The optional third argument is the newline to use. This defaults to `"\n"`. In some special circumstances, you might want something else like `"\r\n"` or any other newline marker.
* The final optional argument is the block that specifies how to build spaces. It receives a single argument which is the number of spaces to generate. This defaults to printing the specified number of space characters. You would modify this only in special circumstances.

### Print width

It's important to note that this is different than a maximum line width on a linter. When linting, you want to enforce that nothing exceeds a certain width. In a printer, you're saying that this width is what makes things most readable. So for example, if you were printing some Ruby code like:

```ruby
if some_very_long_condition.some_very_long_method_name(some_very_long_argument)
  do_something
end
```

In this case you wouldn't want your print width to be set much more than `80`, since it would attempt to print this all on one line, which is much less readable.

### Building the tree

Now that you have a printer created, you can start to build out the tree. Each of the nodes of the tree is a small object that you can inspect manually. They each have convenience methods on the printer object that should be used to create them. We'll start by talking about the most foundational nodes, then move on to the less commonly-used ones.

#### `Text`

This node contains literal text to be printed. It can wrap any object, but by convention it is normally a string. These objects will never be broken up. For the printing algorithm to work properly, they shouldn't contain newline characters. To instantiate one and add it to the tree, you call the `text` command:

```ruby
q.text("my content")
```

If you're using an object that isn't a string and doesn't respond to `#length`, you will need to additionally specify the width of the object, which is the optional second argument, as in:

```ruby
q.text(content, 1)
```

#### `Breakable`

This node specifies where in an expression a line break could be inserted. If the expression fits on one line, the line break will be replaced by its separator. Line breaks by default indent the next line with the current level of indentation. To instantiate one and add it to the tree, you call the `breakable` command:

```ruby
q.breakable
```

When it fits on one line, that will be replaced by a space. If you want to change that behavior, you can specify the first argument to be whatever you like. Commonly it will be an empty string, as in:

```ruby
q.breakable("")
```

As with `Text`, if you're using an object that isn't a string and doesn't respond to `#length`, you will need to additionally specify the width of the object, which is the optional second argument, as in:

```ruby
q.breakable(newline, 1)
```

By default, breakables will indent the next line to the current level of indentation. This is desirable in most cases since if you're inside a parent node that has indented by - for instance, 3 levels - you wouldn't want the next content to start at the beginning of the next line. However, in some circumstances you want control over this behavior, which you can control through the optional `indent` keyword, as in:

```ruby
q.breakable(indent: false)
```

There are some times when you want to force a newline into the output and not check whether or not it fits on the current line. You need this behavior if, for instance, you're printing Ruby code and you need to put a separator between two statements. To force the newline into the output, you can use the optional `force`  keyword, as in:

```ruby
q.breakable(force: true)
```

There are a few circumstances where you'll want to force the newline into the output but not insert a break parent (because you don't want to necessarily force the groups to break unless they need to). In this case you can pass `force: :skip_break_parent` to breakable and it will not insert a break parent.

```ruby
q.breakable(force: :skip_break_parent)
```

### `Group`

This node marks a group of items which the printer should try to fit on one line. Groups are usually nested, and the printer will try to fit everything on one line, but if it doesn't fit it will break the outermost group first and try again. It will continue breaking groups until everything fits (or there are no more groups to break).

Breaks are propagated to all parent groups, so if a deeply nested expression has a forced break, everything will break. This only matters for forced breaks, i.e. newlines that are printed no matter what and can be statically analyzed.

To instantiate a group and add it to the tree, you call the `group` method, as in:

```ruby
q.group {}
```

It accepts a block that specifies the contents of the group. Within that block you would continue to call other node building methods. By default, this is all you need to specify, as it will group its contents automatically. You can optionally specify open and close segments that should be printed before and after the group, as well as specify how indented the contents of the group should be printed, as in:

```ruby
q.group(2, "[", "]") {}
```

In the above example, `"["` will always be printed before the group contents and `"]"` will always be printed after. If the group breaks, its contents will be indented by 2 spaces. As with `Text`, if you're using an object for the open or close segment that isn't a string and doesn't respond to `#length`, you will need to additionally specify the width of the objects, as in:

```ruby
q.group(2, opening, closing, 1, 1) {}
```

#### `Align`

This node increases the indentation by a fixed number of spaces or a string. It is automatically created within `Group` nodes if a width is specified. To instantiate one and add it to the tree, you call the `nest` method, as in:

```ruby
q.nest(2) {}
```

It accepts a block that specifies the contents of the alignment node. The value that you're indenting by can be positive or negative.

#### `BreakParent`

This node forces all parent groups up to this point in the tree to break. It's useful if you have some condition under which you must force all of the newlines into the output buffer. To instantiate one and add it to the tree, you call the `break_parent` method, as in:

```ruby
q.break_parent
```

#### `IfBreak`

This node allows you to represent the same content in two different ways: one for if the parent group breaks, one for if it doesn't. For example, if you were writing a formatter for Ruby code, you could use this node to print an `if` statement in the modifier form _only_ if it fits on one line. Otherwise, you could provide the multi-line form. To instantiate one and add it to the tree, you call the `if_break` method, as in:

```ruby
q.if_break {}
```

It accepts a block that specifies the contents that should be printed in the event that the parent group is broken. It returns an object that responds to `if_flat`, which you can use to specify the contents that should be printed in the event that the parent group is unbroken, as in:

```ruby
q.if_break {}.if_flat {}
```

If you have contents that should _only_ be printed in the case that the parent is group is unbroken (like a `then` keyword in Ruby after a `when` inside a `case` statement), you can just call `if_flat` directly on the printer, as in:

```ruby
q.if_flat {}
```

#### `Indent`

This node is a variant on the `Align` node that always indents by exactly one level of indentation. It's basically a shortcut for calling `nest(2)`. To instantiate one and add it to the tree, you call the `indent` method, as in:

```ruby
q.indent {}
```

It accepts a block that specifies the contents that should be indented.

#### `LineSuffix`

There are times when you want something to be printed, but only just before the subsequent newline. It's not practical to constantly check where the line ends to avoid accidentally printing something in the middle of the line. This node instead buffers other nodes passed to it and flushes them before any newline. It can be used to implement trailing comments, for example, that should be printed after all source code has been flushed. To instantiate one and add it to the tree, you call the `line_suffix` method, as in:

```ruby
q.line_suffix {}
```

It accepts a block that specifies the contents that should be printed before the next newline.

#### `Trim`

This node trims all the indentation on the current line. It's a very niche use case, but necessary in specific circumstances. For example, if you're in the middle of a deeply indented node, but absolutely have to print the next content at the beginning of the next line (think something like `=begin` comments in Ruby). To instantiate one and add it to the tree, you call the `trim` method, as in:

```ruby
q.trim
```

Note that trim will only work if the output buffer supports modifying its contents, e.g., an array that we can call `pop` on.

### Helpers

When you're determining how to build your print tree, there are a couple of utilities that are provided to address some common use cases. They are listed below.

#### `current_group`

`current_group` returns the most-recently created group being built (i.e., the group whose block is being executed). Usually you won't need to access this information, as it's mostly here as a reflection API.

```ruby
q.current_group
```

#### `comma_breakable`

`comma_breakable` is a shortcut for calling `q.text(",")` and then `q.breakable` immediately after. It's relatively common when printing lists.

```ruby
q.comma_breakable
```

#### `fill_breakable`

Similar to `breakable`, except wrapped in a group. This is useful if you're trying to fill a line of contents as opposed to breaking every item up individually. This can transform output from:

```ruby
item1
item2
item3
item4
item5
```

to

```ruby
item1 item2 item3
item4 item5
```

Contrast that will `breakable`, where everything would be forced onto its own line if it were in the same group.

```ruby
q.fill_breakable
```

This method accepts the same arguments as the [breakable](#breakable) method.

#### `seplist`

Creates a separated list of elements, by default separated by the `comma_breakable` method. It will yield each element to a block that can be customized printing behavior for each one. For example, to print a separated array:

```ruby
q.seplist(%w[one two three]) { |element| q.text(element) }
```

This will result in commas and breakables being inserted between each element. To customize that separator, pass a proc as the second argument, as in:

```ruby
separator = -> { q.text(" - ") }
q.seplist(%w[one two three], separator) { |element| q.text(element) }
```

If you're printing a list of elements and want to specify which method is called to create the iterator, you can pass an optional third argument that defaults to `:each`, as in:

```ruby
pairs = { one: "a", two: "b", three: "c" }
separator = -> { q.comma_breakable }

q.seplist(pairs, separator, :each_pair) do |(key, value)|
  q.text(key)
  q.text("=")
  q.text(value)
end
```

#### `target`

`target` returns the current array that is being used to capture calls to node builder methods. It is always the contents of the most recently built node. For example, if you create a group and are inside the block specifying the contents, `target` will return the group's contents array. Usually you won't need to access this information, as it's mostly here as a reflection API.

```ruby
q.target
```

#### `with_target`

This method is used internally to control which node is currently capturing content from the node builder methods. You can optionally use it if, for some reason, you need the printer to put all of its contents into a specific array.

```ruby
target = []
q.with_target(target) {}
```

### Printing the tree

Now that the tree has been built, you can print its contents using the `flush` method. This will flush all of the contents of the printer to the output buffer specified when the printer was created. For example:

```ruby
q.flush
```

When `flush` is called, the output buffer receives the `<<` method for however many text segments ended up getting printed. For convenience, since creating a printer, building a tree, and printing a tree is so common, you can use the `PrettierPrinter.format` method, as in:

```ruby
PrettierPrinter.format(+"") do |q|
  q.text("content")
end
```

This method will automatically call `flush` after the block has been run and return the output buffer.

### Examples

All of these APIs are made much more clear by a couple of examples. Below are a couple that should help elucidate how these methods fit together.

#### Printing an array

Let's say you wanted to pretty-print an array of strings. You would:

```ruby
def print_array(array)
  PrettierPrinter.format(+"") do |q|
    q.text("[")
    q.indent do
      q.breakable("")
      q.seplist(array) { |element| q.text(element) }
    end

    q.breakable("")
    q.text("]")
  end
end
```

#### Printing a hash

Let's say you wanted to pretty-print a hash with symbol keys and string values. You would:

```ruby
def print_hash(hash)
  PrettierPrinter.format(+"") do |q|
    q.text("{")
    q.indent do
      q.breakable

      q.seplist(hash, -> { q.comma_breakable }) do |(key, value)|
        q.group do
          q.text(key)
          q.text(":")

          q.indent do
            q.breakable
            q.text(value)
          end
        end
      end
    end

    q.breakable
    q.text("}")
  end
end
```

#### Printing arithmetic

Let's say you had some arithmetic nodes that you wanted to print out recursively. You would:

```ruby
Binary = Struct.new(:left, :operator, :right, keyword_init: true)

def print_binary(q, node)
  case node
  in Binary[left:, operator:, right:]
    q.group do
      print_binary(q, left)
      q.text(" ")
      q.text(operator)

      q.indent do
        q.breakable
        print_binary(q, right)
      end
    end
  else
    q.text(node)
  end
end

node =
  Binary.new(
    left: Binary.new(left: "1", operator: "+", right: "2"),
    operator: "*",
    right:
      Binary.new(
        left: "3",
        operator: "-",
        right: Binary.new(left: "5", operator: "*", right: "6")
      )
  )

puts PrettierPrint.format(+"") { |q| print_binary(q, node) }
```

#### Printing a file system

Let's say you wanted to print out a file system like the `tree` command. You would:

```ruby
def print_directory(q, entries)
  grouped = entries.group_by { _1.include?("/") ? _1[0..._1.index("/")] : "." }

  q.seplist(grouped["."], -> { q.breakable }) do |entry|
    if grouped.key?(entry)
      q.text(entry)
      q.indent do
        q.breakable
        print_directory(q, grouped[entry].map! { _1[(entry.length + 1)..] })
      end
    else
      q.text(entry)
    end
  end
end

puts PrettierPrint.format(+"") { |q| print_directory(q, Dir["**/*"]) }
```

#### Other examples

There are lots of other examples that you can look at in other gems and files. Those include:

* [test/prettier_print_test.rb](test/prettier_print_test.rb) - the test file for this gem
* [Syntax Tree](https://github.com/ruby-syntax-tree/syntax_tree) - a formatter for Ruby code
* [Syntax Tree HAML plugin](https://github.com/ruby-syntax-tree/syntax_tree-haml) - a formatter for the HAML template language
* [Syntax Tree RBS plugin](https://github.com/ruby-syntax-tree/syntax_tree-rbs) - a formatter the RBS type specification language

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ruby-syntax-tree/prettier_print.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
