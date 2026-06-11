require "paint"
class TronBlockMonitorJob < ApplicationJob
  queue_as :default

  # 配置参数
  INITIAL_BACKFILL_COUNT = 8  # 首次启动或断档时回溯的整点区块数量
  MINIMUM_TIME_FOR_TRANSFER = 20  # 机器人策略执行所需的最短时间（秒）

  # 用于数据库锁的记录（只需一条记录）
  LOCK_RECORD_ID = 1

  def perform
    lock = MonitorLock.find_or_create_by(id: LOCK_RECORD_ID)
    lock.with_lock do
      execute_monitor_logic()
    end
  rescue ActiveRecord::LockWaitTimeout => e
     puts Paint[".... [Skip] 其他 Job 正在执行，跳过本次 ....", :red]
  rescue => e
     Rails.logger.error "TronBlockMonitorJob 执行异常: #{e.message}"
     puts Paint[".... Job 执行异常: #{e.message} ....", :red]
  end

  private

  def execute_monitor_logic
    latest_block = fetch_latest_block
    return unless latest_block

    latest_num = latest_block["block_header"]["raw_data"]["number"]
    current_target = (latest_num / 20) * 20

    # puts Paint[".... New 【#{latest_num}】 → Target 【#{current_target}】 .... Fetch 【#{Time.now}】 ....", :gray] unless Rails.env.production?

    last_processed = BlockRecord.maximum(:number).to_i || 0

    if last_processed == 0
      handle_first_run(current_target)
    elsif current_target > last_processed
      handle_normal_run(current_target, last_processed)
    else
      # Rails.logger.info ".... No strategy, Next ...."
    end
  end

  # ====================== 首次运行 ======================
  def handle_first_run(current_target)
    logger.info Paint[".... First startup，Synchronize #{INITIAL_BACKFILL_COUNT} blocks ....", :yellow]
    # 计算起始区块号（当前整点区块向前推4个，加上当前共5个）
    start_num = [current_target - (INITIAL_BACKFILL_COUNT - 1) * 20, 20].max
    # 保存前n-1个历史区块，不触发机器人策略
    (start_num...(current_target)).step(20) do |block_number|
      save_block_quietly(block_number)
    end
    # 保存最新的区块，并触发机器人策略
    save_block_and_trigger(current_target)
  end

  # ====================== 正常运行 ======================
  def handle_normal_run(current_target, last_processed)
    return if current_target <= last_processed
    missing_blocks = (current_target - last_processed) / 20

    if missing_blocks == 1
      save_block_and_trigger(current_target)
    else
      logger.info Paint[".... #{missing_blocks} blocks lost， #{last_processed} → #{current_target} ....", :yellow]

      backfill_count = [missing_blocks, INITIAL_BACKFILL_COUNT].min
      start_num = current_target - (backfill_count - 1) * 20

      logger.info Paint[".... Filling in #{backfill_count} blocks ....", :yellow]

      (start_num...current_target).step(20) do |num|
        save_block_quietly(num)
      end

      save_block_and_trigger(current_target)
    end
  end

  # 安静保存区块，不触发机器人策略
  def save_block_quietly(block_number)
    return if BlockRecord.exists?(number: block_number)
    block_data = fetch_block_by_number(block_number)
    # 最多做一次备用尝试
    if block_data.nil?
      sleep 0.1
      block_data = fetch_block_by_number(block_number)
    end
    return unless block_data
    if block_data
      save_block_record(block_data)
      logger.info ".... 【Old】 Save 【#{block_number}】 .... Time 【#{Time.now}】 ...."
    end
  end

  # 保存区块并触发机器人策略（有时间判断）
  def save_block_and_trigger(block_number)
    return if BlockRecord.exists?(number: block_number)
    block_data = fetch_block_by_number(block_number)
    # 最多做一次备用尝试（符合你“尽量一次成功”的要求）
    if block_data.nil?
      sleep 0.1
      block_data = fetch_block_by_number(block_number)
    end
    return unless block_data
    # 保存区块记录
    block_record = save_block_record(block_data)
    return unless block_record
    # puts Paint[".... Save 【#{block_number}】 .... Time 【#{Time.now}】 ....", :green]
    # Rails.logger.info ".... Save 【#{block_number}】 .... Time 【#{Time.now}】 .... Parity #{block_record.parity} ...."
    # 判断时间是否足够执行机器人策略
    if enough_time_for_transfer?(block_record.block_time)
      trigger_bot_monitoring
    end
  end

  # 区块时间是以UTC存储的，转换为本地时间: block_time.localtime
  def enough_time_for_transfer?(block_time)
    # 全部使用 UTC 计算，安全可靠
    elapsed_seconds = Time.now.utc.to_i - block_time.to_i
    # 计算距离下一个整点还剩多少秒
    remaining_seconds = 60 - (elapsed_seconds % 60)
    if remaining_seconds >= MINIMUM_TIME_FOR_TRANSFER
      true
    else
      logger.info Paint[".... ⚠ 区块已过 #{elapsed_seconds}s，剩余约 #{remaining_seconds}s，时间不足，跳过机器人 ....", :red]
      false
    end
  end

  # 机器人策略监控
  def trigger_bot_monitoring
    latest_block = BlockRecord.last
    return unless latest_block

    active_bots = Bot.where(status: [ :running, :waiting_result ])
    return unless active_bots.any?

    logger.info Paint[".... #{active_bots.count} active robot, 【#{latest_block.number}】 ....", :blue]

    active_bots.each do |bot|
      begin
        bot.process_new_block(latest_block)
      rescue => e
        logger.error ".... Bot #{bot.id} 处理新区块出错: #{e.message} ...."
      end
      sleep 0.15
    end
  end

  def fetch_latest_block
    uri = URI("https://api.trongrid.io/wallet/getnowblock")
    response = Net::HTTP.get_response(uri)
    return unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  rescue => e
    logger.error ".... Fetch new false: #{e.message} ...."
    nil
  end

  def fetch_block_by_number(num)
    url = URI("https://api.trongrid.io/wallet/getblockbynum")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request["accept"] = "application/json"
    request["content-type"] = "application/json"
    request["TRON-PRO-API-KEY"] = Rails.application.credentials.dig(:trongrid_api_key_block)
    request.body = { num: num }.to_json

    response = http.request(request)
    return unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  rescue => e
    logger.error ".... Fetch #{num} by number false: #{e.message} ...."
    nil
  end

  def save_block_record(block_data)
    raw = block_data["block_header"]["raw_data"]
    block_id = block_data["blockID"]
    timestamp_ms = raw["timestamp"]

    block_time = Time.at(timestamp_ms / 1000.0).utc
    last_digit = block_id.reverse[/\d/] || "0"
    parity = last_digit.to_i.odd? ? 1 : 0

    BlockRecord.create!(
      number:      raw["number"],
      block_hash:  block_id,
      last_digit:  last_digit,
      parity:      parity,
      block_time:  block_time
    )
  rescue ActiveRecord::RecordInvalid => e
    logger.error ".... Save block false: #{e.message} ...."
    nil
  end
end
