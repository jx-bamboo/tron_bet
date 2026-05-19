class CreateBots < ActiveRecord::Migration[8.1]
  def change
    create_table :bots do |t|
      t.references :member, null: false, foreign_key: true
      t.integer :status, default: 0 # running stopped paused waiting
      t.string :strategy_type # 会员绑定的策略 zl2 zl3
      t.integer :consecutive_count, null: false, default: 0 # 连续次数
      t.integer :current_parity # 当前单 | 双, 如果有下注，则记录 ----重要
      t.integer :failed_times, null: false, default: 0 # 失败次数 ----重要
      t.integer :bet_amount_index, default: 0 # 记录下注金额，方便计算 ----重要
      t.string :last_checked_block # 最后检查区块
      t.decimal :start_balance, precision: 20, scale: 6 # 启动初始余额
      t.decimal :end_balance, precision: 20, scale: 6 # 停止结束余额
      t.decimal :profit, precision: 20, scale: 6 # 盈利
      t.datetime :started_at # 开始时间
      t.datetime :stopped_at # 结束时间
      t.integer :monitor_count # 监控次数
      t.timestamps
    end
  end
end
