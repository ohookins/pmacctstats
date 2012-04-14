# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20101116201752) do

  create_table "hosts", :force => true do |t|
    t.string   "ip"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "usage_entries", :force => true do |t|
    t.integer  "host_id"
    t.decimal  "in",         :precision => 8, :scale => 2
    t.decimal  "out",        :precision => 8, :scale => 2
    t.date     "date"
    t.datetime "created_at",                               :null => false
    t.datetime "updated_at",                               :null => false
  end

  # FIXME: This is only here so tests succeed. Find a way to load fixtures into
  # multiple test databases.
  create_table "acct" do |t|
    t.string    "mac_src"
    t.string    "mac_dst"
    t.string    "ip_src"
    t.string    "ip_dst"
    t.integer   "src_port"
    t.integer   "dst_port"
    t.string    "ip_proto"
    t.integer   "packets"
    t.integer   "bytes"
    t.datetime  "stamp_inserted"
    t.datetime  "stamp_updated"
  end
end
