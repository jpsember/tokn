require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/test*.rb']
end

Rake::TestTask.new("test:only") do |t|
  t.libs << "test"
  t.test_files = FileList["test/test_priority.rb"]
end

