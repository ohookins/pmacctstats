require 'rubygems'
require 'mysql'
require 'ipaddr'
require 'bigdecimal'
require 'inifile'

class NoConfFileError < Exception; end
class UnreadableConfFileError < Exception; end
class MissingConfSectionError < Exception; end
class EmptyConfSectionError < Exception; end
class MissingConfValueError < Exception; end

class Summarise
  # define some constants used throughout the summarisation
  CONFIGFILE = '/etc/pmacctstats.conf'
  CONFIGPARTS = [:main, :source, :destination]
  STARTDATE = '2010-01-01'

  # Database and network settings
  @@sourcehost = nil
  @@sourcedb = nil
  @@sourceuser = nil
  @@sourcepass = nil
  @@desthost = nil
  @@destdb = nil
  @@destuser = nil
  @@destpass = nil
  @@localnets = nil

  private
  # reasonably naive logging shortcut
  def self.log (msglevel, msg, loglevel = 0)
    if msglevel and msg and loglevel >= msglevel then
        puts msg
    end
  end 

  # shortcut for outputting the current method call name
  def self.this_method_name
    caller[0] =~ /`([^']*)'/ and $1
  end 

  # Return path to configuration file. This makes testing easier.
  def self.config_file
    CONFIGFILE
  end

  # Parse configuration file
  def self.get_config
    # File must exist and at least be readable
    File.file?(self.config_file) or raise NoConfFileError
    File.readable?(self.config_file) or raise UnreadableConfFileError

    conf = IniFile.load(config_file)
    
    # Check all necessary sections exist
    CONFIGPARTS.each do |c|
      conf.has_section?(c) or raise MissingConfSectionError, c
      conf[c] == {} and raise EmptyConfSectionError, c
    end

    # Populate our variables
    @@sourcehost = conf[:source]['host']
    @@sourcedb = conf[:source]['database']
    @@sourceuser = conf[:source]['username']
    @@sourcepass = conf[:source]['password']
    @@desthost = conf[:destination]['host']
    @@destdb = conf[:destination]['database']
    @@destuser = conf[:destination]['username']
    @@destpass = conf[:destination]['password']
    @@localnets = conf[:main]['networks'].delete(' ').split(',')

    # Check we have all values
    emptyvars = []
    self.class_variables.each do |v|
      (eval v) == nil and emptyvars.push(v)
    end
    unless emptyvars == [] then
      e = ''
      emptyvars.each { |v| e.concat("#{v} ") }
      raise MissingConfValueError, e.chomp(' ')
    end
  end

  # shortcut for matching an IP in one of our valid subnets
  def self.matches_subnets? (ip)
    unless ip
      return false
    else
      ip_obj = nil
      begin
        ip_obj = IPAddr.new(ip)
      rescue ArgumentError
        log(0, "Invalid IP address #{ip} caught in #{this_method_name}")
        return false
      end
      @@localnets.each do |n|
        IPAddr.new(n).include?(ip_obj) and return true
      end
      return false
    end
  end

  # adds an ip (host) entry to the rails database
  def self.add_ip(params = {:dconn => nil, :ip => nil, :loglevel => 0})
    insert_id = nil
    params[:dconn].class == Mysql or raise "#{this_method_name} was not passed a valid MySQL connection."
    IPAddr.new(params[:ip]) or raise "#{this_method_name} was not passed a valid IP address."

    # check the IP is not already there
    stmt = "SELECT id FROM hosts WHERE ip = \'#{params[:ip]}\'"
    log(2, stmt, params[:loglevel])
    res = params[:dconn].query(stmt)
    if res and res.num_rows() >= 1 then
      if res.num_rows() > 1 then
        raise "#{params[:ip]} found multiple times in the hosts table, this should not happen."
      end
      insert_id = res.fetch_row()
      log(2, "#{params[:ip]} found at ID #{insert_id} in hosts table.", params[:loglevel])
      res.free

    # didn't find the IP address in the table, so add it
    else
      begin
        stmt = "INSERT INTO hosts (id, ip, created_at, updated_at) VALUES (NULL, \'#{params[:ip]}\', NOW(), NOW())"
        log(2, stmt, params[:loglevel])
        params[:dconn].query(stmt)
        insert_id = params[:dconn].insert_id
        log(2, "#{params[:ip]} inserted at ID #{insert_id}", params[:loglevel])
        params[:dconn].commit
      rescue => detail
        params[:dconn].rollback
        raise "insertion of #{params[:ip]} failed and was rolled back in #{this_method_name} => #{detail}"
      end
    end
    return insert_id
  end

  # add usage for local IPs for a date to the rails database
  def self.add_usage(params = {:sconn => nil, :dconn => nil, :date => nil, :loglevel => nil})
    # NOTE: Since MySQL does not have built-in useful IP address functions like PostgreSQL,
    # we are forced to grab all rows and do filtering in the app. This may become unfeasible
    # when the daily stats become too large. ### IN (\'#{foo.keys * %q{','}}\')

    stmt = "SELECT ip_src,ip_dst,bytes FROM acct WHERE DATE(stamp_inserted) = \'#{params[:date]}\'"
    log(2, stmt, params[:loglevel])
    res = params[:sconn].query(stmt)
    res and log(2, "number of rows: #{res.num_rows()}", params[:loglevel])

    # Process each row in the result set and tally the bytes for each valid IP
    source_matched = 0 # purely diagnostic tracking
    dest_matched = 0 # ditto
    bytesbyip = {} # keep a hash of our matched IPs and their byte counters like {IP => [inbytes, outbytes]}
    res and res.each_hash do |r|
      if matches_subnets?(r['ip_src']) and not matches_subnets?(r['ip_dst']) then
        source_matched += 1
        bytesbyip[r['ip_src']] or bytesbyip[r['ip_src']] = [0,0] # create a record in the hash if missing
        bytesbyip[r['ip_src']][1] += r['bytes'].to_i
      elsif matches_subnets?(r['ip_dst']) and not matches_subnets?(r['ip_src']) then
        dest_matched += 1
        bytesbyip[r['ip_dst']] or bytesbyip[r['ip_dst']] = [0,0] # create a record in the hash if missing
        bytesbyip[r['ip_dst']][0] += r['bytes'].to_i
      end
    end
    res and res.free
    log(1, "source_matched: #{source_matched} for #{params[:date]}", params[:loglevel])
    log(1, "dest_matched: #{dest_matched} for #{params[:date]}", params[:loglevel])
    log(2, bytesbyip.each { |k,v| puts "#{k}: #{v[0]} in, #{v[1]} out" }, params[:loglevel])

    # Finally, insert the usage data into the rails usage_entries table
    bytesbyip.each do |k,v|
      stmt = "SELECT id FROM hosts WHERE ip = \'#{k}\'"
      log(2, stmt, params[:loglevel])
      res = params[:dconn].query(stmt)
      id = nil
      unless res and res.num_rows() == 1 then
        log(0, "#{this_method_name} wasn't able to find #{k} in the database, but it has usage data.", params[:loglevel])
        next
      else
        id = res.fetch_row()[0]
      end

      # Add the record now, convert numbers from bytes to MB in fixed decimal
      begin
        inMB = (BigDecimal.new(v[0].to_s)/(1024**2)).round(2).to_f
        outMB = (BigDecimal.new(v[1].to_s)/(1024**2)).round(2).to_f
        stmt = "INSERT INTO usage_entries VALUES (NULL, #{id}, \'#{inMB}\', \'#{outMB}\', \'#{params[:date]}\', NOW(), NOW())"
        params[:dconn].query(stmt)
        params[:dconn].commit
      rescue => detail
        params[:dconn].rollback
        raise "Error while inserting usage for #{params[:date]} in #{this_method_name} => #{detail}"
      end
    end
  end

  public
  # the guts of the usage summarisation
  def self.run (loglevel = 0)
    import_date = nil
    import_list = []
    self.get_config

    begin
      # establish source database connection (raw pmacct database)
      sconn = Mysql::connect(@@sourcehost, @@sourceuser, @@sourcepass, @@sourcedb)
      unless sconn
        fail("Couldn't connect to database #{@@sourcedb} with #{@@sourceuser}@#{@@sourcehost} with given password.")
      end
      sconn.autocommit(0)

      # establish destination database connection
      dconn = Mysql::connect(@@desthost, @@destuser, @@destpass, @@destdb)
      unless dconn
        fail("Couldn't connect to database #{@@destdb} with #{@@destuser}@#{@@desthost} with given password.")
      end
      dconn.autocommit(0)
    rescue
      sconn && sconn.close
    end

    begin
      # Determine our cut-off date for the latest stats.
      # This is an arbitrary date cut-off in the case of no pre-existing stats.
      stmt = "SELECT COALESCE((SELECT MAX(date) FROM usage_entries), \'#{STARTDATE}\') AS date"
      log(2, stmt, loglevel)
      res = dconn.query(stmt)
      if res and res.num_rows() == 1 then
        import_date = res.fetch_row()
        log(1, "last import date: #{import_date}", loglevel)
        res.free
      else
        fail('Unable to determine last usage import date, or use a default value.')
      end

      # Determine list of days we have to process.
      # We don't want to import today's stats as we won't have the complete day's stats.
      stmt = "SELECT DISTINCT(DATE(stamp_inserted)) AS date FROM acct WHERE DATE(stamp_inserted) > \'#{import_date}\' AND DATE(stamp_inserted) < DATE(NOW()) ORDER BY date"
      log(2, stmt, loglevel)
      res = sconn.query(stmt)
      if res and res.num_rows() >= 1 then
        res.each do |r|
          r_date = r[0]
          r_date.class == String and import_list.push(r_date) and log(1, "need to import: #{r_date}", loglevel)
        end
        res.free
      else
        log(1, "Nothing to import", loglevel)
        return(0)
      end

      # Run import for each missing day of stats
      import_list.each do |d|
        log(1, "Now importing from date: #{d}", loglevel)

        # Determine list of active IPs and check them against our local subnets.
        # MySQL can't do the calculations natively, sadly.
        stmt = "SELECT DISTINCT(ip_src) AS ip FROM acct WHERE DATE(stamp_inserted) = \'#{d}\' UNION DISTINCT SELECT DISTINCT(ip_dst) AS ip FROM acct WHERE DATE(stamp_inserted) = \'#{d}\'"
        log(2, stmt, loglevel)
        res = sconn.query(stmt)

        # Pick out valid IP addresses and add them to the "hosts" rails table
        valid_ips = []
        res and res.each do |r|
          if matches_subnets?(r[0]) then
            log(1, "Found valid IP address: #{r[0]}", loglevel)
            add_ip({:dconn => dconn, :ip => r[0], :loglevel => loglevel})
          end
        end
        res and res.free

        # Summarise traffic 
        add_usage({:sconn => sconn, :dconn => dconn, :date => d, :loglevel => loglevel})
      end 
    rescue => detail
      log(0, detail, loglevel)
    ensure
      log(1, "Closing source connection", loglevel)
      sconn.close
      log(1, "Closing destination connection", loglevel)
      dconn.close
    end
  end
end
