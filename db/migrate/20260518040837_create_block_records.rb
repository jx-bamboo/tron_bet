class CreateBlockRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :block_records do |t|
      t.string :number
      t.string :block_hash
      t.integer :last_digit
      t.integer :parity # 0 双数， 1 单数
      t.datetime :block_time
      t.timestamps
    end
    add_index :block_records, :number,     unique: true
    add_index :block_records, :block_hash,       unique: true
    add_index :block_records, :block_time, unique: true
  end
end
