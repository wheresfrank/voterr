class CreateSolidCableMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :solid_cable_messages do |t|
      t.string :channel, null: false
      t.string :data, null: false
      t.datetime :created_at, null: false
    end

    add_index :solid_cable_messages, [:channel, :created_at]
  end
end
