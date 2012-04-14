# Add the lib directory to the load path
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))

require 'summarise'

desc 'Summarise all of the unprocessed pmacct data into the pmacctstats database'
task :summarise do
  summarise = Summarise.new()
  summarise.loglevel = 1
  summarise.run()
end
