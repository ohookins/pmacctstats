# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_pmacctstats_session',
  :secret      => '075501fd175b883f8253a12983b3e2f79a8774405915408a7da7aa37c1f6cf42852a6767688f67ecbf363b8031a96b5b2f0d13af5d14a1b0a497532c558bf0f2'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
