require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/test*.rb']
end

Rake::TestTask.new("test:only") do |t|
  t.libs << "test"
  t.test_files = FileList["test/test_filter.rb"]
end

desc "Recompile sample tokens"
task :sampletokens do
  chdir("test") do
    system("tokncompile < sampletokens.txt > compileddfa.txt")
  end
end
