require 'spec_helper'
require 'lib/summarise'
require 'fileutils'
require 'inifile'

describe Summarise do
  fixtures :usage_entries
  fixtures :acct

  before(:each) do
    # Set up a location for a test configuration file
    @@tmpfile = "/tmp/summarisetest.#{$$}"
  end

  after(:each) do
    # Remove the directory if it was created
    File.unlink(@@tmpfile) if File.exist?(@@tmpfile)
  end

  describe '#this_method_name' do
    it 'returns the correct calling method name' do
      subject.instance_eval {
        def dummy_method
          this_method_name()
        end
      }
      subject.dummy_method.should == 'dummy_method'
    end
  end

  describe '#matches_subnets?' do
    it 'returns true if the address matches one of the IPv4 subnets' do
      # Set up the list of local subnets
      subject.instance_eval do
        @settings[:localnets] = ['192.0.2.0/24']
      end

      subject.matches_subnets?('192.0.2.1').should be_true
    end

    it 'returns true if the address matches one of the IPv6 subnets' do
      # Set up the list of local subnets
      subject.instance_eval do
        @settings[:localnets] = ['fe80::/64']
      end

      subject.matches_subnets?('fe80::1234:dead:beef:cafe').should be_true
    end

    it 'returns false if the address does not match any subnets' do
      # Set up the list of local subnets
      subject.instance_eval do
        @settings[:localnets] = ['192.0.2.0/24']
      end

      subject.matches_subnets?('127.0.0.1').should be_false
    end

    it 'returns false if an empty address was passed in' do
      # stub the logger so we don't get additional output
      subject.should_receive(:log).and_return(true)
      subject.matches_subnets?('').should be_false
    end

    it 'returns false if nil was passed in' do
      subject.matches_subnets?(nil).should be_false
    end

    it 'can find a match in an array of networks' do
      subject.instance_eval do
        @settings[:localnets] = ['192.0.2.0/25','192.0.2.128/25']
      end
      subject.matches_subnets?('192.0.2.1/32').should be_true
    end
  end

  describe '#get_config' do
    # mock the location of the config file
    before(:each) do
      subject.should_receive(:config_file).at_least(:once).and_return(@@tmpfile)
    end

    it 'raises an exception when the config file is absent' do
      expect { subject.get_config }.to raise_error(NoConfFileError)
    end

    it 'raises an exception when the config file is inaccessible' do
      FileUtils.touch(@@tmpfile)
      FileUtils.chmod(0000, @@tmpfile)
      expect { subject.get_config }.to raise_error(UnreadableConfFileError)
    end

    it 'raises an exception when sections are missing in the config file' do
      FileUtils.touch(@@tmpfile)
      expect { subject.get_config }.to raise_error(MissingConfSectionError)
    end

    it 'raises an exception when there are empty sections in the config file' do
      conf = IniFile.new(@@tmpfile)
      conf[:main]
      conf[:source]
      conf[:destination]
      conf.save
      expect { subject.get_config }.to raise_error(EmptyConfSectionError)
    end

    it 'raises an exception when it encounters an empty config variable' do
      conf = IniFile.new(@@tmpfile)
      conf[:main]
      conf[:source]
      conf[:destination]
      conf[:main][:networks] = ''
      conf[:source][:host] = ''
      conf[:destination][:host] = ''
      conf.save
      expect { subject.get_config }.to raise_error(MissingConfValueError)
    end

    it 'does not raise an exception when the configuration is complete' do
      conf = IniFile.new(@@tmpfile)
      conf[:main]
      conf[:source]
      conf[:destination]
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
      expect { subject.get_config }.to_not raise_error
    end
  end

  describe '#connect_activerecord' do
    it 'connects the source and destination databases separately' do
      pending
    end
  end

  describe '#last_import_date' do
    it 'retrieves the most recent import date correctly when one exists' do
      # relies on the fixtures
      subject.last_import_date().should == Date::civil(2010, 11, 3)
    end

    it 'falls back to the default when a most recent import date does not exist' do
      # delete all entries so the database is empty
      UsageEntry.delete_all()
      subject.last_import_date().should == Date::civil(2010, 01, 01)
    end
  end

  describe '#find_unimported_days' do
    # mock out the current date
    before(:each) do
      subject.should_receive(:current_civil_date).and_return(Date::civil(2010,11,7))
    end

    it 'retrieves a list of unimported days of accounting data when some are present' do
      subject.find_unimported_days(Date::civil(2010,11,3)).should ==
        [Date::civil(2010,11,4), Date::civil(2010,11,5), Date::civil(2010,11,6)]
    end

    it 'returns [] when there are no accounting data in the database' do
      # delete all the fixture records
      PmacctEntry.delete_all()
      subject.find_unimported_days(Date::civil(2010,11,3)).should == []
    end

    it 'returns [] when all accounting data in the database has already been processed' do
      # X > Date::civil(y,m,d) equates to the start of day d (i.e. 00:00)
      PmacctEntry.where('stamp_inserted > ?', Date::civil(2010,11,4)).delete_all()
      subject.find_unimported_days(Date::civil(2010,11,3)).should == []
    end
  end

  describe '#get_active_addresses' do
    it 'returns [] when there was no activity on a given day' do
      PmacctEntry.delete_all()
      subject.get_active_addresses(Date::civil(2010,11,3)).should == []
    end

    it 'returns [] when no local addresses were found in the data for a given day' do
      # mock out calls to validate addresses
      subject.should_receive(:matches_subnets?).once.with('192.0.2.1').and_return(false)
      subject.should_receive(:matches_subnets?).once.with('192.0.2.2').and_return(false)
      subject.get_active_addresses(Date::civil(2010,11,3)).should == []
    end

    it 'returns a list of local active addresses from accounting data for a given day' do
      # mock out calls to validate addresses
      subject.should_receive(:matches_subnets?).once.with('192.0.2.1').and_return(true)
      subject.should_receive(:matches_subnets?).once.with('192.0.2.2').and_return(true)
      subject.get_active_addresses(Date::civil(2010,11,3)).should == ['192.0.2.1','192.0.2.2']
    end
  end

  describe '#add_active_hosts' do
  end

  describe '#get_daily_usage' do
    # Set up the list of local subnets
    before(:each) do
      subject.instance_eval do
        @settings[:localnets] = ['192.0.2.0/24']
      end
    end

    it 'returns {} when there was no activity on a given day' do
      subject.get_daily_usage(Date::civil(2010,11,10)).should == {}
    end

    it 'returns {} when there was only activity by non-local hosts on a given day' do
      subject.get_daily_usage(Date::civil(2010,11,7)).should == {}
    end

    it 'returns {} when there was only activity between local hosts on a given day' do
      subject.get_daily_usage(Date::civil(2010,11,4)).should == {}
    end

    it 'returns a summary of daily usage by ip when there was valid activity' do 
      subject.get_daily_usage(Date::civil(2010,11,5)).should == {'192.0.2.1' => {:in => 0, :out => 100}}
    end
  end

  describe '#insert_daily_usage' do

    it 'should insert no new records when there is no usage for the day' do
      # given
      day = Date::civil(2011,1,1)

      # when
      subject.insert_daily_usage({}, day)

      # then
      UsageEntry.where(:date => day).count.should == 0
    end

    it 'should create a new host entry when one was not found' do
      # given
      day = Date::civil(2011,1,1)

      # when
      subject.insert_daily_usage({'192.0.2.1' => {:in => 1048576, :out => 2097152}}, day)
      host_entry = Host.where(:ip => '192.0.2.1').first

      # then
      host_entry.should_not be_nil
      host_entry.id.should == 1
    end

    it 'should reuse a host entry when one was found' do
      # given
      day = Date::civil(2011,1,1)

      # when
      Host.new(:ip => '192.0.2.1').save
      subject.insert_daily_usage({'192.0.2.1' => {:in => 1048576, :out => 2097152}}, day)
      host_entry = Host.where(:ip => '192.0.2.1').first

      # then
      host_entry.should_not be_nil
      host_entry.id.should == 1
    end

    it 'should correctly insert usage information for a host' do
      # given
      day = Date::civil(2011,1,1)
      UsageEntry.delete_all()

      # when
      subject.insert_daily_usage({'192.0.2.1' => {:in => 1048576, :out => 2097152}}, day)
      usage_entry = UsageEntry.find(:all).first

      # then
      usage_entry.in.should == 1.00
      usage_entry.out.should == 2.00
    end
  end
end
