require 'rubygems'
require 'mysql'
require 'ipaddr'

class Summarise
    CONFIG   = Rails::Configuration.new
    HOST     = CONFIG.database_configuration[RAILS_ENV]["host"]
    SOURCEDB = 'pmacct'
    DESTDB   = CONFIG.database_configuration[RAILS_ENV]["database"]
    USERNAME = CONFIG.database_configuration[RAILS_ENV]["username"]
    PASSWORD = CONFIG.database_configuration[RAILS_ENV]["password"]
    STARTDATE = '2010-01-01'
    LOCALNETS = ['192.168.1.0/24'] # supports both IPv4 and IPv6


    def self.log (msglevel, msg, loglevel = 0)
        if msglevel and msg and loglevel >= msglevel then
            puts msg
        end
    end 

    def self.run (loglevel = 0)
        import_date = ''
        import_list = []

        begin
            # establish source database connection (raw pmacct database)
            sconn = Mysql::connect(HOST, USERNAME, PASSWORD, SOURCEDB)
            unless sconn
                fail("Couldn't connect to database #{SOURCEDB} with #{USERNAME}@#{HOST} with given password.")
            end
            sconn.autocommit(0)

            # establish destination database connection
            dconn = Mysql::connect(HOST, USERNAME, PASSWORD, DESTDB)
            unless dconn
                fail("Couldn't connect to database #{DESTDB} with #{USERNAME}@#{HOST} with given password.")
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
            else
                fail('Unable to determine last usage import date, or use a default value.')
            end

            # Determine list of days we have to process
            stmt = "SELECT DISTINCT(DATE(stamp_inserted)) AS date FROM acct WHERE stamp_inserted > \'#{import_date}\' ORDER BY date"
            log(2, stmt, loglevel)
            res = sconn.query(stmt)
            if res then
                if res.num_rows() >= 1 then
                    res.each do |r|
                        r_date = r[0]
                        r_date.class == String and import_list.push(r_date) and log(1, "need to import: #{r_date}", loglevel)
                    end
                else
                    log(1, "Nothing to import", loglevel)
                    return(0)
                end
            else
                raise "Nothing returned from query #{stmt}"
            end

            # Run import for each missing day of stats
            import_list.each do |i|
                log(1, "Now importing from date: #{i}", loglevel)

                # Determine list of active IPs and check them against our local subnets.
                # MySQL can't do the calculations natively, sadly.
                stmt = "SELECT DISTINCT(ip_src) AS ip FROM acct WHERE DATE(stamp_inserted) = \'#{i}\' UNION DISTINCT SELECT DISTINCT(ip_dst) AS ip FROM acct WHERE DATE(stamp_inserted) = \'#{i}\'"
                log(2, stmt, loglevel)
                res = sconn.query(stmt)

                # Create IPAddr objects of all our subnets to test against
                localnets = []
                LOCALNETS.each do |n|
                    localnets.push(IPAddr.new(n))
                end

                # Pick out valid IP addresses and collect them
                valid_ips = []
                if res then
                    res.each do |r|
                        r_ip = IPAddr.new(r[0])
                        localnets.each do |n|
                            n.include?(r_ip) and valid_ips.push(r_ip.to_s) and log(1, "Found valid IP address: #{r_ip.to_s}", loglevel)
                        end
                    end
                end
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
