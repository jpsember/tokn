# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tokn/version'

Gem::Specification.new do |spec|
  spec.name          = "tokn"
  spec.version       = Tokn::VERSION
  spec.authors       = ["Jeff Sember"]
  spec.email         = ["jpsember@gmail.com"]

  spec.summary       = "Extracts tokens from text using regular expressions"
  spec.description   = <<"DESC"
Given a script containing token descriptions (each a regular expression),
tokn compiles an automaton which it can then use to efficiently convert a
text file to a sequence of those tokens.
DESC
  spec.homepage      = "https://github.com/jpsember/tokn"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "trollop"
  spec.add_runtime_dependency "js_base", "~> 1.0"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
end
