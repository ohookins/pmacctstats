class CreateUsageEntries < ActiveRecord::Migration
  def self.up
    create_table :usage_entries do |t|
      t.decimal :in
      t.decimal :out
      t.date :date

      t.timestamps
    end
  end

  def self.down
    drop_table :usage_entries
  end
end
