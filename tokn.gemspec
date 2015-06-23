require 'rake'

Gem::Specification.new do |s|
  s.name        = 'tokn'
  s.version     = '2.0.0'
  s.date        = Time.now
  s.summary     = 'Extracts tokens from source files'

  s.description = <<"DESC"
Given a script containing token descriptions (each a regular expression),
tokn compiles an automaton which it can then use to efficiently convert a
text file to a sequence of those tokens.
DESC

  s.authors     = ["Jeff Sember"]
  s.email       = "jpsember@gmail.com"
  s.homepage    = 'http://www.cs.ubc.ca/~jpsember/'
  s.files = FileList['lib/**/*.rb',
                      'bin/*',
                      '[A-Z]*',
                      'test/**/*',
                      ]

  s.add_dependency('js_base','~> 1.0')
  s.add_dependency('trollop')

  s.bindir = 'bin'
  s.executables   = FileList['bin/*'].map{|x| File.basename(x)}
  s.test_files = Dir.glob('test/*.rb')
  s.license = 'mit'
end
