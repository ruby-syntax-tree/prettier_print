# frozen_string_literal: true

require "test_helper"
require "pp"

class PrettierPrint
  class PrettierPrintTest < Test::Unit::TestCase
    test "Align#pretty_print" do
      assert_equal "align0([])\n", PP.pp(Align.new(indent: 0), +"")
    end

    test "Breakable#pretty_print" do
      assert_equal "breakable\n", PP.pp(Breakable.new, +"")
    end

    test "Breakable#pretty_print force=true" do
      assert_equal "breakable(force=true)\n", PP.pp(Breakable.new(force: true), +"")
    end

    test "Breakable#pretty_print indent=false" do
      assert_equal "breakable(indent=false)\n", PP.pp(Breakable.new(indent: false), +"")
    end

    test "BreakParent#pretty_print" do
      assert_equal "break-parent\n", PP.pp(BreakParent.new, +"")
    end

    test "Group#pretty_print" do
      assert_equal "group([])\n", PP.pp(Group.new(0), +"")
    end

    test "Group#pretty_print break" do
      assert_equal "breakGroup([])\n", PP.pp(Group.new(0).tap(&:break), +"")
    end

    test "IfBreak#pretty_print" do
      assert_equal "if-break([], [])\n", PP.pp(IfBreak.new, +"")
    end

    test "Indent#pretty_print" do
      assert_equal "indent([])\n", PP.pp(Indent.new, +"")
    end

    test "LineSuffix#pretty_print" do
      assert_equal "line-suffix([])\n", PP.pp(LineSuffix.new, +"")
    end

    test "Text#pretty_print" do
      assert_equal "text([])\n", PP.pp(Text.new, +"")
    end

    test "Trim#pretty_print" do
      assert_equal "trim\n", PP.pp(Trim.new, +"")
    end

    test "Buffer::StrinfBuffer#trim!" do
      buffer = Buffer::StringBuffer.new
      buffer << "......"
      buffer << +"...   "
      buffer << "      "
      buffer << "\t\t\t"
      buffer << "\t \t "

      buffer.trim!
      assert_equal ".........", buffer.output
    end

    test "Buffer::ArrayBuffer#trim!" do
      buffer = Buffer::ArrayBuffer.new
      buffer << "......"
      buffer << +"...   "
      buffer << "      "
      buffer << "\t\t\t"
      buffer << "\t \t "

      buffer.trim!
      assert_equal ".........", buffer.output.join
    end

    test "PrettierPrint#nest" do
      result =
        PrettierPrint.format do |q|
          q.nest(4) do
            q.breakable(force: true)
            q.text("content")
          end
        end

      assert_equal "\n    content", result
    end

    test "PrettierPrint#breakable(indent: false)" do
      result =
        PrettierPrint.format do |q|
          q.nest(4) do
            q.breakable_return
            q.text("content")
          end
        end

      assert_equal "\ncontent", result
    end

    test "PrettierPrint#break_parent" do
      result =
        PrettierPrint.format do |q|
          q.if_break { q.text("break") }.if_flat { q.text("flat") }
          q.break_parent
        end

      assert_equal "break", result
    end

    test "PrettierPrint#if_break" do
      result =
        PrettierPrint.format do |q|
          q.if_break { q.text("break") }.if_flat { q.text("flat") }
        end

      assert_equal "flat", result
    end

    test "PrettierPrint#if_flat" do
      result =
        PrettierPrint.format do |q|
          q.if_flat { q.text("flat") }
        end

      assert_equal "flat", result
    end

    test "PrettierPrint#indent" do
      result =
        PrettierPrint.format do |q|
          q.indent do
            q.breakable_force
            q.text("content")
          end
        end

      assert_equal "\n  content", result
    end

    test "PrettierPrint#line_suffix" do
      result =
        PrettierPrint.format do |q|
          q.line_suffix { q.text(" # suffix") }
          q.text("content")
          q.breakable_force
        end

      assert_equal "content # suffix\n", result
    end

    test "PrettierPrint#trim" do
      result =
        PrettierPrint.format do |q|
          q.indent do
            q.breakable_force
            q.text("first content")
            q.breakable_force
            q.trim
            q.text("second content")
          end
        end

      assert_equal "\n  first content\nsecond content", result
    end

    test "PrettierPrint pushing strings" do
      result =
        PrettierPrint.format do |q|
          q.target << "content"
        end

      assert_equal "content", result
    end

    test "PrettierPrint pushing unknown objects" do
      q = PrettierPrint.new([])
      q.target << Object.new
      q.target << "content"
      q.flush
      q.output.shift
      assert_equal "content", q.output.join
    end

    test "PrettierPrint#last_position string" do
      q = PrettierPrint.new
      assert_equal 5, q.last_position(".....")
    end

    test "PrettierPrint#last_position group" do
      q = PrettierPrint.new
      q.text(".....")

      assert_equal 5, q.last_position(q.groups.first)
    end

    test "PrettierPrint#last_position breakable" do
      q = PrettierPrint.new
      q.text(".....")
      q.breakable
      q.text("...")

      assert_equal 3, q.last_position(q.groups.first)
    end

    test "PrettierPrint#last_position if break" do
      q = PrettierPrint.new
      q.text(".....")
      q.if_break { q.text("...") }

      assert_equal 8, q.last_position(q.groups.first)
    end
  end
end
