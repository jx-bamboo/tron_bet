class CreateTronWallets < ActiveRecord::Migration[8.1]
  def change
    create_table :tron_wallets do |t|
      t.string :address, index: true
      t.string :private_key, index: true
      t.decimal :balance
      t.integer :status, default: 0, null: false
      t.references :member, null: true, foreign_key: true
      t.timestamps
    end
  end
end
