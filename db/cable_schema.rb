# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_18_042110) do
  create_table "admins", force: :cascade do |t|
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "locked_at"
    t.string "name"
    t.string "phone"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.integer "sign_in_count", default: 0, null: false
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_admins_on_confirmation_token", unique: true
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["name"], name: "index_admins_on_name", unique: true
    t.index ["phone"], name: "index_admins_on_phone", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_admins_on_unlock_token", unique: true
  end

  create_table "bet_records", force: :cascade do |t|
    t.decimal "bet_amount"
    t.integer "bet_parity"
    t.integer "block_record_id", null: false
    t.integer "bot_id", null: false
    t.datetime "created_at", null: false
    t.text "note"
    t.integer "result_parity"
    t.integer "status"
    t.boolean "success"
    t.string "transaction_id"
    t.datetime "updated_at", null: false
    t.index ["block_record_id"], name: "index_bet_records_on_block_record_id"
    t.index ["bot_id"], name: "index_bet_records_on_bot_id"
  end

  create_table "block_records", force: :cascade do |t|
    t.string "block_hash"
    t.datetime "block_time"
    t.datetime "created_at", null: false
    t.integer "last_digit"
    t.string "number"
    t.integer "parity"
    t.datetime "updated_at", null: false
    t.index ["block_hash"], name: "index_block_records_on_block_hash", unique: true
    t.index ["block_time"], name: "index_block_records_on_block_time", unique: true
    t.index ["number"], name: "index_block_records_on_number", unique: true
  end

  create_table "bots", force: :cascade do |t|
    t.integer "bet_amount_index", default: 0
    t.integer "consecutive_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "current_parity"
    t.decimal "end_balance", precision: 20, scale: 6
    t.integer "failed_times", default: 0, null: false
    t.string "last_checked_block"
    t.integer "member_id", null: false
    t.integer "monitor_count"
    t.decimal "profit", precision: 20, scale: 6
    t.decimal "start_balance", precision: 20, scale: 6
    t.datetime "started_at"
    t.integer "status", default: 0
    t.datetime "stopped_at"
    t.string "strategy_type"
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_bots_on_member_id"
  end

  create_table "members", force: :cascade do |t|
    t.boolean "active", default: false
    t.datetime "created_at", null: false
    t.integer "status", default: 0
    t.string "strategy", null: false
    t.string "tron_address", null: false
    t.string "tron_private_key", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", limit: 1024, null: false
    t.integer "channel_hash", limit: 8, null: false
    t.datetime "created_at", null: false
    t.binary "payload", limit: 536870912, null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "strategies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.string "type_name"
    t.datetime "updated_at", null: false
  end

  create_table "transaction_logs", force: :cascade do |t|
    t.decimal "amount"
    t.integer "block_record_id", null: false
    t.datetime "created_at", null: false
    t.integer "member_id", null: false
    t.json "raw_data"
    t.string "status"
    t.string "transaction_hash"
    t.string "transaction_type"
    t.datetime "updated_at", null: false
    t.index ["block_record_id"], name: "index_transaction_logs_on_block_record_id"
    t.index ["member_id"], name: "index_transaction_logs_on_member_id"
  end

  create_table "tron_wallets", force: :cascade do |t|
    t.string "address"
    t.decimal "balance"
    t.datetime "created_at", null: false
    t.integer "member_id"
    t.string "private_key"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["address"], name: "index_tron_wallets_on_address"
    t.index ["member_id"], name: "index_tron_wallets_on_member_id"
    t.index ["private_key"], name: "index_tron_wallets_on_private_key"
  end

  add_foreign_key "bet_records", "block_records"
  add_foreign_key "bet_records", "bots"
  add_foreign_key "bots", "members"
  add_foreign_key "transaction_logs", "block_records"
  add_foreign_key "transaction_logs", "members"
  add_foreign_key "tron_wallets", "members"
end
