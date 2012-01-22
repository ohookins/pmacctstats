# Add the lib directory to the load path
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..')))

require 'summarise'

desc 'Summarise all of the unprocessed pmacct data into the pmacctstats database'
task :summarise do
  Summarise.run(1)
end
