class CreateMonitorLocks < ActiveRecord::Migration[8.1]
  def change
    create_table :monitor_locks do |t|
      t.timestamps
    end
  end
end
