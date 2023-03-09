# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.1] - 2023-03-09

### Changed

- Fixed a bug where having line suffixes on the final line without a breakable could cause an infinite loop.

## [1.2.0] - 2022-12-23

### Added

- You can now supply the base indentation level for the output buffer.

## [1.1.0] - 2022-11-08

### Added

- `prettier_print` now works with Ractors.

## [1.0.2] - 2022-10-19

### Changed

- Fix trailing whitespace stripping to not including newlines.

## [1.0.1] - 2022-10-18

### Changed

* `breakable_return` - should also break parent

## [1.0.0] - 2022-10-17

### Added

* `breakable_space` - a shortcut for `breakable`
* `breakable_empty` - a shortcut for `breakable("")`
* `breakable_force` - a shortcut for `breakable("", force: true)`
* `breakable_return` - a shortcut for `breakable(" ", indent: false, force: true)`
* Strings can now be added directly to the output buffer, which means they don't have to be placed into the `Text` node. This cuts down on quite a bit of allocations.

### Changed

* `trim` now strips its whitespace using `rstrip!` instead of a custom `gsub!`. This means that other forms of whitespace beyond tabs and spaces are included. This shouldn't really impact anyone unless they're using vertical tab or something in combination with `trim` and wanted them to stay in.

### Removed

* There is no longer a `PrettierPrint::DefaultBuffer` class. Since there were only ever two implementations, those implementations now no longer share a parent.
* `PrettierPrint::IndentLevel` is now entirely gone. This was mostly an implementation detail, and no one should have been relying on it anyway. However, it means that the ability to use nest with a string literal is now gone as well. It can be created again by using seplist though, so the functionality just isn't there in the shortcut version. This means we're able to keep track of indentation as a single integer again, which drastically simplifies the code.

## [0.1.0] - 2022-05-13

### Added

- 🎉 Initial release! 🎉

[unreleased]: https://github.com/ruby-syntax-tree/prettier_print/compare/v1.2.1...HEAD
[1.2.1]: https://github.com/ruby-syntax-tree/prettier_print/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/ruby-syntax-tree/prettier_print/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/ruby-syntax-tree/prettier_print/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/ruby-syntax-tree/prettier_print/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/ruby-syntax-tree/prettier_print/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/ruby-syntax-tree/prettier_print/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/ruby-syntax-tree/prettier_print/compare/df51ce...v0.1.0
