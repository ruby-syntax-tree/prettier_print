# frozen_string_literal: true

return unless defined?(Ractor)
require "test_helper"

class PrettierPrint
  class RactorTest < Test::Unit::TestCase
    test "ractor safe" do
      result =
        Ractor.new do
          PrettierPrint.format([]) do |q|
            q.group do
              q.text("# This is the main class for the PrettierPrint gem.")
              q.breakable_force

              q.text("class ")
              q.group { q.text("PrettierPrint") }

              q.indent do
                q.breakable_force

                q.trim
                q.text("=begin")
                q.breakable_return
                q.text("This is embedded documentation.")
                q.breakable_return
                q.text("=end")
                q.breakable_force

                q.group do
                  q.text("def ")
                  q.text("format(")

                  q.group { q.seplist(%w[foo bar baz]) { |item| q.text(item) } }

                  q.text(")")
                  q.breakable_force
                  q.text("end")
                end
              end

              q.breakable_force
              q.text("end")
            end

            q.breakable_force
          end
        end

      expected = <<~RUBY
        # This is the main class for the PrettierPrint gem.
        class PrettierPrint
        =begin
        This is embedded documentation.
        =end
          def format(foo, bar, baz)
          end
        end
      RUBY

      assert_equal expected, result.take.join
    end
  end
end
