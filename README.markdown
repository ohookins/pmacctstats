pmacctstats
===========

Overview
--------

"pmacctstats" is a Ruby on Rails application which provides a dynamic summary view of collected traffic information from [pmacct](http://www.pmacct.net/), an excellent traffic accounting package for IPv4 and IPv6.

Requirements
------------

Development is currently on Ubuntu 10.10, and using the following versions:

* Ruby 1.8.7
* Gems:
    * actionmailer (2.3.5)
    * actionpack (2.3.5)
    * activerecord (2.3.5)
    * activeresource (2.3.5)
    * activesupport (2.3.5)
    * rails (2.3.5)
    * mysql (2.8.1)
    * inifile (0.4.1)
    * mocha (0.9.8) - if you want to run unit tests
* libmysqlclient14
* MySQL 5.1.41-3ubuntu12.7

Usage
-----

Put the source somewhere, start up script/server like you usually would, or run through Passenger or some other webserver (only tested with built-in Webrick so far).

Import of pmacct data
---------------------

Please create a configuration file, "/etc/pmacctstats.conf" containing the following information:

    [main]
    networks = '192.0.2.0/24'

    [source]
    database = 'pmacct'
    host = 'localhost'
    username = 'pmacct'
    password = 'secret'

    [destination]
    database = 'pmacctstats'
    host = 'localhost'
    username = 'pmacctstats'
    password = 'secret'

It at least needs to be readable by the user you run pmacctstats as.

* lib/summarise.rb contains the logic for importing the traffic data.
* You can (in fact MUST right now) run it manually from rake:
    * rake summarise
* I suggest you schedule this from cron at the moment, to run some time after midnight, to import the previous day's stats.
