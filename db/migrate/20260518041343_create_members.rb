class CreateMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :members do |t|
      t.string :username, null: false
      t.string :tron_address, null: false
      t.string :tron_private_key, null: false
      t.string :strategy, null: false
      t.boolean :active, default: false
      t.integer :status, default: 0
      t.timestamps
    end
  end
end
