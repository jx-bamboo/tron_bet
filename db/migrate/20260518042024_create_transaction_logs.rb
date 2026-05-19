class CreateTransactionLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :transaction_logs do |t|
      t.references :member, null: false, foreign_key: true
      t.string :transaction_type
      t.decimal :amount
      t.string :transaction_hash
      t.string :status
      t.references :block_record, null: false, foreign_key: true
      t.json :raw_data
      t.timestamps
    end
  end
end
