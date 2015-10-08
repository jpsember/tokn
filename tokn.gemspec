require 'rake'

Gem::Specification.new do |s|
  s.name        = 'tokn'
  s.version     = '2.2.4'
  s.executables = FileList['bin/*'].map{|x| File.basename(x)}
  s.summary     = 'Extracts tokens from source files'
  s.description = <<-"EOS"
Given a script containing token descriptions (each a regular expression),
tokn compiles an automaton which it can then use to efficiently convert a
text file to a sequence of those tokens.
  EOS
  s.authors     = ['Jeff Sember']
  s.email       = 'jpsember@gmail.com'
  s.files = FileList['lib/**/*.rb',
                      'bin/*',
                      '[A-Z]*',
                      'test/**/*',
                      ]
  s.homepage    = 'https://github.com/jpsember/tokn'
  s.license = 'MIT'

  s.add_dependency('js_base','~> 1.0')
  s.add_dependency('trollop')
end
