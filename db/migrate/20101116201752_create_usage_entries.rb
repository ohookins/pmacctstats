class CreateUsageEntries < ActiveRecord::Migration
  def self.up
    create_table :usage_entries do |t|
      t.integer :host_id
      t.decimal :in, :precision => 8, :scale => 2
      t.decimal :out, :precision => 8, :scale => 2
      t.date :date

      t.timestamps
    end
  end

  def self.down
    drop_table :usage_entries
  end
end
