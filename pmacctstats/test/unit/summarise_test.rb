require 'test/unit'
require 'mocha'
require 'lib/summarise'
require 'fileutils'
require 'inifile'

class SummariseTest < Test::Unit::TestCase
  @@tmpfile = "/tmp/summarisetest.#{$$}"

  # Test teardown handler
  def teardown
    case self.name
      when 'test_get_config(SummariseTest)' then
        # Remove the directory again
        File.unlink(@@tmpfile)
    end
  end

  # Test getting a valid configuration
  def test_get_config
    # no config file at all
    Summarise.expects(:config_file).returns(@@tmpfile).at_least_once
    assert_raise NoConfFileError do
      Summarise.get_config
    end

    # unable to access config file
    FileUtils.touch(@@tmpfile)
    FileUtils.chmod(0000, @@tmpfile)
    assert_raise UnreadableConfFileError do
      Summarise.get_config
    end

    # missing sections in config file
    FileUtils.chmod(0644, @@tmpfile)
    assert_raise MissingConfSectionError do
      Summarise.get_config
    end

    # empty sections
    conf = IniFile.new(@@tmpfile)
    conf[:main]
    conf[:source]
    conf[:destination]
    conf.save
    assert_raise EmptyConfSectionError do
      Summarise.get_config
    end

    # empty variable
    conf[:main][:networks] = ''
    conf[:source][:host] = ''
    conf[:destination][:host] = ''
    conf.save
    assert_raise MissingConfValueError do
      Summarise.get_config
    end

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
    assert_nothing_raised do
      Summarise.get_config
    end

    # Check we can pass an array of networks
    conf[:main][:networks] = '192.0.2.0/25,192.0.2.128/25'
    conf.save
    assert_nothing_raised do
      Summarise.get_config
      assert_equal(true, Summarise.matches_subnets?('192.0.2.1/32'))
    end
  end
end
