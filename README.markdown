pmacctstats
===========

Overview
--------

"pmacctstats" is a Ruby on Rails application which provides a dynamic summary view of collected traffic information from [pmacct](http://www.pmacct.net/), an excellent traffic accounting package for IPv4 and IPv6.

Requirements
------------

* Ruby 1.8.7
* Gems listed in Gemfile (use bundler)
* libmysqlclient14
* MySQL 5.1.41-3ubuntu12.7

Usage
-----

Put the source somewhere, start up script/server like you usually would, or run through Passenger or some other webserver (only tested with built-in Webrick so far).

Import of pmacct data
---------------------

### Configuration file
Please create a configuration file, "/etc/pmacctstats.conf" containing the following information:

    [main]
    networks = 192.0.2.0/24,fe80::/64

    [source]
    database = pmacct
    host = localhost
    username = pmacct
    password = secret

    [destination]
    database = pmacctstats
    host = localhost
    username = pmacctstats
    password = secret

* It at least needs to be readable by the user you run pmacctstats as.
* Multiple local network designations must be comma-separated.
* IPv4 and IPv6 are supported.

### Importing
* lib/summarise.rb contains the logic for importing the traffic data.
* You can (in fact MUST right now) run it manually from rake:
    * rake summarise
* I suggest you schedule this from cron at the moment, to run some time after midnight, to import the previous day's stats.

Testing
-------
In its infinite wisdom, Rails 3 will attempt to populate your testing database
from the development database before running tests. If you don't feel like
keeping MySQL around all the time for testing just run the following:

RAILS_ENV='test' rake db:migrate
RAILS_ENV='test' rake test
