class CreateBetRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :bet_records do |t|
      t.references :bot, null: false, foreign_key: true
      t.references :block_record, null: false, foreign_key: true
      t.integer :bet_parity # 投注单双（0双1单）
      t.decimal :bet_amount # 投注金额
      t.integer :result_parity # 结果单双
      t.boolean :success # nil: 已经下注, true： 下注赢了, false： 下注输了
      t.string :transaction_id
      t.integer :status # 状态 pending, conpleted, failed 暂时不用
      t.text :note
      t.timestamps
    end
  end
end
