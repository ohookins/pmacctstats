require 'rubygems'
require 'active_record'
require 'ipaddr'
require 'bigdecimal'
require 'inifile'
require 'app/models/pmacct_entry'
require 'app/models/usage_entry'
require 'app/models/host'

class NoConfFileError < Exception; end
class UnreadableConfFileError < Exception; end
class MissingConfSectionError < Exception; end
class EmptyConfSectionError < Exception; end
class MissingConfValueError < Exception; end

class Summarise
  # define some constants used throughout the summarisation
  CONFIGFILE = '/etc/pmacctstats.conf'
  CONFIGPARTS = [:main, :source, :destination]
  STARTDATE = Date::civil(2010, 01, 01)

  attr_accessor :loglevel

  def initialize()
    @loglevel = 0

    # Database and network settings
    @settings = {:sourcehost => nil,
                  :sourcedb   => nil,
                  :sourceuser => nil,
                  :sourcepass => nil,
                  :desthost   => nil,
                  :destdb     => nil,
                  :destuser   => nil,
                  :destpass   => nil,
                  :localnets  => nil
                 }
  end

  # reasonably naive logging shortcut
  def log (msglevel, msg, loglevel = 0)
    if msglevel and msg and loglevel >= msglevel then
        puts msg
    end
  end

  # shortcut for outputting the current method call name
  def this_method_name
    caller[0] =~ /`([^']*)'/ and $1
  end

  # Return path to configuration file. This makes testing easier.
  def config_file
    CONFIGFILE
  end

  # Parse configuration file
  def get_config
    # File must exist and at least be readable
    File.file?(config_file) or raise NoConfFileError
    File.readable?(config_file) or raise UnreadableConfFileError

    conf = IniFile.load(config_file)

    # Check all necessary sections exist
    CONFIGPARTS.each do |c|
      raise(MissingConfSectionError, c) unless conf.has_section?(c)
      raise(EmptyConfSectionError, c) if conf[c] == {}
    end

    # Populate our variables
    @settings[:sourcehost] = conf[:source]['host']
    @settings[:sourcedb] = conf[:source]['database']
    @settings[:sourceuser] = conf[:source]['username']
    @settings[:sourcepass] = conf[:source]['password']
    @settings[:desthost] = conf[:destination]['host']
    @settings[:destdb] = conf[:destination]['database']
    @settings[:destuser] = conf[:destination]['username']
    @settings[:destpass] = conf[:destination]['password']
    @settings[:localnets] = conf[:main]['networks'].delete(' ').split(',')

    # Check we have all values
    emptyvars = []
    @settings.each_pair do |k,v|
      emptyvars.push(k) if v.nil?
    end
    unless emptyvars == [] then
      e = ''
      emptyvars.each { |v| e.concat("#{v} ") }
      raise MissingConfValueError, e.chomp(' ')
    end
  end

  # shortcut for matching an IP in one of our valid subnets
  def matches_subnets? (ip)
    if ! ip
      return false
    else
      ip_obj = nil
      begin
        ip_obj = IPAddr.new(ip)
      rescue ArgumentError
        log(0, "Invalid IP address #{ip} caught in #{self.this_method_name}")
        return false
      end
      @settings[:localnets].each do |n|
        IPAddr.new(n).include?(ip_obj) and return true
      end
      return false
    end
  end

  # adds an host object to the rails database
  def add_active_hosts(day)
  end

  # get usage for local IPs for a date from the pmacct database
  def get_daily_usage(day)
    # This is very inefficient. When the result set becomes too big to fit in memory
    # we may have to map/reduce or hack cursors into AR later.
    log(2, "Pulling out usage data for #{day}", @loglevel)
    usage = PmacctEntry.where('stamp_inserted > ? AND stamp_inserted < ?',
                                day.strftime('%Y-%m-%d 00:00'),
                                (day+1).strftime('%Y-%m-%d 00:00')
                                ).all({:select => ['ip_src','ip_dst','bytes']})
    log(2, "number of rows: #{usage.count()}", @loglevel)

    # Process each row in the result set and tally the bytes for each valid IP
    source_matched = 0 # purely diagnostic tracking
    dest_matched = 0 # ditto
    # keep a hash of our matched IPs and their byte counters like:
    # {IP => {:in => inbytes, :out => outbytes}}
    bytes_by_ip = {}

    usage.each do |row|
      # Egress bandwidth
      if matches_subnets?(row.ip_src) and not matches_subnets?(row.ip_dst) then
        source_matched += 1
        bytes_by_ip[row.ip_src] or bytes_by_ip[row.ip_src] = {:in => 0, :out => 0} # create a record in the hash if missing
        bytes_by_ip[row.ip_src][:out] += row.bytes
      # Ingress bandwidth
      elsif matches_subnets?(row.ip_dst) and not matches_subnets?(row.ip_src) then
        dest_matched += 1
        bytes_by_ip[row.ip_dst] or bytes_by_ip[row.ip_dst] = {:in => 0, :out => 0} # create a record in the hash if missing
        bytes_by_ip[row.ip_dst][:in] += row.bytes
      end
    end
    log(1, "source_matched: #{source_matched} for #{day}", @loglevel)
    log(1, "dest_matched: #{dest_matched} for #{day}", @loglevel)
    log(2, bytes_by_ip.each_pair { |host,usage| "#{host}: #{usage[:in]} in, #{usage[:out]} out" }, @loglevel)

    return bytes_by_ip
  end

  def insert_daily_usage(bytes_by_ip, day)
    # Loop over each valid host
    bytes_by_ip.each_pair do |ip,usage|

      # Find the object or create a new one for this host
      host_obj = Host.where(:ip => ip).first
      if host_obj.nil? then
        Host.new(:ip => ip).save
        host_obj = Host.where(:ip => ip).first
        log(2, "Created new host object with id #{host_obj.id} for #{ip}", @loglevel)
      else
        log(2, "Found host object with id #{host_obj.id} for #{ip}", @loglevel)
      end

      # Add usage data for this host.
      # We convert numbers from bytes to MB in fixed decimal
      inMB = (BigDecimal.new(usage[:in].to_s)/(1024**2)).round(2).to_f
      outMB = (BigDecimal.new(usage[:out].to_s)/(1024**2)).round(2).to_f
      UsageEntry.new(:host_id => host_obj.id,
                     :in      => inMB,
                     :out     => outMB,
                     :date    => day.strftime('%Y-%m-%d')).save
    end
  end

  # connect up the ruby on rails database to the default ActiveRecord::Base
  # adaptor, and the source pmacct database to an adaptor specific to that
  # subclass
  def connect_activerecord()
    # FIXME: parameterise the adaptor
    ActiveRecord::Base.establish_connection(:adaptor  => 'mysql2',
                                            :host     => @settings[:desthost],
                                            :username => @settings[:destuser],
                                            :password => @settings[:destpass],
                                            :database => @settings[:destdb])
    PmacctEntry.establish_connection(:adaptor  => 'mysql2',
                                     :host     => @settings[:sourcehost],
                                     :username => @settings[:sourceuser],
                                     :password => @settings[:sourcepass],
                                     :database => @settings[:sourcedb])
  end

  # Determine the most recently imported usage date
  def last_import_date()
    log(2, 'Calculating UsageEntry.maximum(:date)', @loglevel)

    # This is an arbitrary date cut-off in the case of no pre-existing stats.
    import_date = UsageEntry.maximum(:date) || STARTDATE
    log(1, "last import date: #{import_date}", @loglevel)

    return import_date
  end

  # Convenience method to facilitate testing
  def current_civil_date()
    Time.now.strftime('%Y-%m-%d')
  end

  # Determine list of days we have to process, given the last
  # successfully imported date.
  def find_unimported_days(import_date)
    # This will be expensive, but it should at least be DB agnostic.
    # Although, this DB should not be indexed anyway, so a row-scan is
    # inevitable.
    import_date += 1 # Need to look from the start of the next day.
    log(2, 'Retrieving unimported rows from database.', @loglevel)
    entries = PmacctEntry.where("stamp_inserted > ? AND stamp_inserted < ?",
                                import_date.strftime('%Y-%m-%d'),
                                current_civil_date()).all(
                                {:select => 'stamp_inserted',
                                :group => 'stamp_inserted',
                                })

    # List of days we have yet to import
    import_list = entries.map { |x| x.stamp_inserted.strftime('%Y-%m-%d') }.uniq

    # Display what needs to be imported
    if import_list.empty?
      log(1, "Nothing to import", @loglevel)
    else
      log(1, import_list.map { |x| "need to import: #{x}" }, @loglevel)
    end
    return import_list
  end

  # For a given date, pull all of the unique addresses seen in the accounting
  # data and match only the ones that we are interested in.
  # Sadly this is quite tricky to do in everything that isn't PostgreSQL
  def get_active_addresses(day)
    log(1, "Now importing from date: #{day.strftime('%Y-%m-%d')}", @loglevel)

    # Determine list of active IPs and check them against our local subnets.
    # This is all local IPs that were a source or destination of traffic.
    log(2, "Determining active IPs for #{day.strftime('%Y-%m-%d')}", @loglevel)
    sources = PmacctEntry.where('stamp_inserted > ? AND stamp_inserted < ?',
                                day.strftime('%Y-%m-%d 00:00'),
                                (day+1).strftime('%Y-%m-%d 00:00')
                                ).uniq.pluck(:ip_src)
    destinations = PmacctEntry.where('stamp_inserted > ? AND stamp_inserted < ?',
                                day.strftime('%Y-%m-%d 00:00'),
                                (day+1).strftime('%Y-%m-%d 00:00')
                                ).uniq.pluck(:ip_dst)

    # Pick out valid IP addresses from our array of sources and destinations on
    # this one day.
    return (sources + destinations).flatten.uniq.map do |address|
      if self.matches_subnets?(address) then
        log(1, "Found valid IP address: #{address}", @loglevel)
        address
      end
    end.compact
  end

  # the guts of the usage summarisation
  def run()
    get_config()

    # Establish the source and destination connections inside ActiveRecord
    connect_activerecord()

    # Determine our cut-off date for the latest stats.
    import_date = last_import_date()

    # Determine list of days we have to process.
    import_list = find_unimported_days(import_date)

    # Run import for each missing day of stats
    import_list.each do |day|
      start_time = Time.now()

      # We have to do a full table scan anyway, so determining active local
      # hosts and adding host objects for them separately to calculating
      # usage information is a pointless performance hit.
      #
      # find the active addresses for the day
      #active_addresses = get_active_addresses(day)

      # ensure each one has a host object
      #add_active_hosts(day)

      # Summarise traffic
      insert_daily_usage(get_daily_usage(day), day)
      log(1, "Stats for #{day} imported in #{(Time.now - start_time).to_i}s", @loglevel)
    end
  end
end
