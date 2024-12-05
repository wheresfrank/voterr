class FixSolidCableMessages < ActiveRecord::Migration[8.0]
  def change
    drop_table :solid_cable_messages
    
    create_table :solid_cable_messages do |t|
      t.binary :channel, null: false, limit: 1024
      t.binary :payload, null: false, limit: 536870912
      t.integer :channel_hash, null: false, limit: 8
      t.datetime :created_at, null: false
    end

    add_index :solid_cable_messages, :channel
    add_index :solid_cable_messages, :channel_hash
    add_index :solid_cable_messages, :created_at
  end
end
