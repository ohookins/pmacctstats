require 'spec_helper'
require 'lib/summarise'
require 'fileutils'
require 'inifile'

describe Summarise do
  before(:each) do
    @@tmpfile = "/tmp/summarisetest.#{$$}"
  end

  after(:each) do
    # Test teardown handler
    #case self.name
      #when 'test_get_config(SummariseTest)' then
        # Remove the directory again
        File.unlink(@@tmpfile)
    #end
  end

  it "can get a valid configuration" do
    # no config file at all
    Summarise.should_receive(:config_file).at_least(:once).and_return(@@tmpfile)
    expect { Summarise.get_config }.to raise_error(NoConfFileError)

    # unable to access config file
    FileUtils.touch(@@tmpfile)
    FileUtils.chmod(0000, @@tmpfile)
    expect { Summarise.get_config }.to raise_error(UnreadableConfFileError)

    # missing sections in config file
    FileUtils.chmod(0644, @@tmpfile)
    expect { Summarise.get_config }.to raise_error(MissingConfSectionError)

    # empty sections
    conf = IniFile.new(@@tmpfile)
    conf[:main]
    conf[:source]
    conf[:destination]
    conf.save
    expect { Summarise.get_config }.to raise_error(EmptyConfSectionError)

    # empty variable
    conf[:main][:networks] = ''
    conf[:source][:host] = ''
    conf[:destination][:host] = ''
    conf.save
    expect { Summarise.get_config }.to raise_error(MissingConfValueError)

    # All variables provided, nothing should go wrong.
    conf[:main][:networks] = 'foo'
    conf[:source][:host] = 'foo'
    conf[:source][:database] = 'foo'
    conf[:source][:username] = 'foo'
    conf[:source][:password] = 'foo'
    conf[:destination][:host] = 'foo'
    conf[:destination][:database] = 'foo'
    conf[:destination][:username] = 'foo'
    conf[:destination][:password] = 'foo'
    conf.save
    expect { Summarise.get_config }.to_not raise_error

    # Check we can pass an array of networks
    conf[:main][:networks] = '192.0.2.0/25,192.0.2.128/25'
    conf.save
    expect { Summarise.get_config }.to_not raise_error
    Summarise.matches_subnets?('192.0.2.1/32').should be_true
  end
end
