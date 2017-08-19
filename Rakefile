require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/test*.rb']
  t.verbose = false
end

desc "Quick experiment"
task :exp do
  system("ruby lib/tokn/experiment.rb < test/exptokens.txt")
end
