# frozen_string_literal: true

require_relative "lib/prettier_print/version"

Gem::Specification.new do |spec|
  spec.name = "prettier_print"
  spec.version = PrettierPrint::VERSION
  spec.authors = ["Kevin Newton"]
  spec.email = ["kddnewton@gmail.com"]

  spec.summary = "A drop-in replacement for the prettyprint gem with more functionality."
  spec.homepage = "https://github.com/ruby-syntax-tree/prettier_print"
  spec.license = "MIT"
  spec.metadata = { "rubygems_mfa_required" => "true" }

  spec.files =
    Dir.chdir(__dir__) do
      `git ls-files -z`.split("\x0")
        .reject { |f| f.match(%r{^(test|spec|features)/}) }
    end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = %w[lib]
end
