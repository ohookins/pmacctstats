pmacctstats
===========

Overview
--------

"pmacctstats" is a Ruby on Rails application which provides a dynamic summary view of collected traffic information from [pmacct](http://www.pmacct.net/), an excellent traffic accounting package for IPv4 and IPv6.

Requirements
------------

Development is currently on Ubuntu 10.04, and using the following versions:

* Ruby 1.8.7
* Gems:
    * Rails 2.3.5
    * Active*/Action* 2.3.5
    * mysql 2.8.1
* libmysqlclient14
* MySQL 5.1.41-3ubuntu12.7

Usage
-----

Put the source somewhere, start up script/server like you usually would, or run through Passenger or some other webserver (only tested with built-in Webrick so far).

Import of pmacct data
---------------------

* lib/summarise.rb contains the logic for importing the traffic data.
* It will import everything available using the same credentials as for the main pmacctstats database (currently).
* You can (in fact MUST right now) run it manually from rake:
    * rake summarise
* I suggest you schedule this from cron at the moment, to run some time after midnight, to import the previous day's stats.
