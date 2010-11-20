require 'rubygems'
require 'mysql'

class Summarise
    CONFIG   = Rails::Configuration.new
    HOST     = CONFIG.database_configuration[RAILS_ENV]["host"]
    SOURCEDB = 'pmacct'
    DESTDB   = CONFIG.database_configuration[RAILS_ENV]["database"]
    USERNAME = CONFIG.database_configuration[RAILS_ENV]["username"]
    PASSWORD = CONFIG.database_configuration[RAILS_ENV]["password"]

    def self.run
        import_date = ''

        begin
            # establish source database connection (raw pmacct database)
            sconn = Mysql::connect(HOST, USERNAME, PASSWORD, SOURCEDB)
            unless sconn
                fail("Couldn't connect to database #{SOURCEDB} with #{USERNAME}@#{HOST} with given password.")
            end

            # establish destination database connection
            dconn = Mysql::connect(HOST, USERNAME, PASSWORD, DESTDB)
            unless dconn
                fail("Couldn't connect to database #{DESTDB} with #{USERNAME}@#{HOST} with given password.")
            end
        rescue
            sconn && sconn.close
        end

        begin
            # Determine our cut-off date for the latest stats.
            # This is an arbitrary date cut-off in the case of no pre-existing stats.
            res = dconn.query('SELECT COALESCE((SELECT MAX(date) FROM usage_entries), "2010-01-01") AS date')
            if res and res.num_rows() == 1 then
                import_date = res.fetch_row()
                puts import_date
            else
                fail('Unable to determine last usage import date, or use a default value.')
            end

            
        rescue
            puts "An exception was raised."
        ensure
            sconn.close
            dconn.close
        end
    end
end
