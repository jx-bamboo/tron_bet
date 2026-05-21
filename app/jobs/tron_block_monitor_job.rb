require "paint"
class TronBlockMonitorJob < ApplicationJob
  queue_as :default

  # 配置参数
  INITIAL_BACKFILL_COUNT = 10  # 首次启动或断档时回溯的整点区块数量
  MINIMUM_TIME_FOR_TRANSFER = 20  # 机器人策略执行所需的最短时间（秒）

  def perform
    latest_block = fetch_latest_block
    return unless latest_block

    latest_num = latest_block["block_header"]["raw_data"]["number"]
    # 只处理整点区块（能被20整除）
    current_target = (latest_num / 20) * 20
    puts Paint[".... New 【#{latest_num}】 → Target 【#{current_target}】 .... Fetch 【#{Time.now}】 ....", :gray]
    # 从数据库获取最后一个已处理的整点区块
    last_processed = BlockRecord.maximum(:number).to_i || 0

    if last_processed == 0
      # 首次运行：保存最近5个整点区块
      handle_first_run(current_target)
    elsif current_target > last_processed
      # 非首次运行
      process_new_target(current_target, last_processed)
      # handle_normal_run(current_target, last_processed)
    else
      Rails.logger.info ".... 尚无新的整点区块（等待下一个） ...."
    end
  end

  def handle_first_run(current_target)
    puts Paint[".... 系统首次启动，开始回溯 #{INITIAL_BACKFILL_COUNT} 个整点区块 ....", :yellow]
    # 计算起始区块号（当前整点区块向前推4个，加上当前共5个）
    start_num = [ current_target - ((INITIAL_BACKFILL_COUNT - 1) * 20), 20 ].max
    # 保存前n-1个历史区块，不触发机器人策略
    (start_num...(current_target)).step(20) do |block_number|
      save_block_quietly(block_number)
    end
    # 保存最新的区块，并触发机器人策略
    save_block_and_trigger(current_target)
  end

  def process_new_target(current_target, last_processed)
    missing_count = (current_target - last_processed) / 20

    if missing_count == 1
      # 正常推进
      save_block_and_trigger(current_target)
    else
      # 有跳跃（之前失败或断档）
      puts Paint[".... 检测到跳跃 #{missing_count} 个整点，从 #{last_processed} → #{current_target} ....", :yellow]
      # 只补最近几个历史 + 当前最新（避免补太多）
      start_num = current_target - (missing_count - 1) * 20
      (start_num...current_target).step(20) do |num|
        save_block_quietly(num)
      end
      save_block_and_trigger(current_target)
    end
  end

  # def handle_normal_run(current_target, last_processed)
  #   if current_target > last_processed
  #     # 计算缺失的整点区块数量
  #     missing_blocks = (current_target - last_processed) / 20

  #     if missing_blocks == 1
  #       # 正常运行：只处理下一个整点区块
  #       next_target = last_processed + 20
  #       save_block_and_trigger(next_target)

  #     elsif missing_blocks <= INITIAL_BACKFILL_COUNT
  #       puts Paint[".... 短暂断档，缺失 #{missing_blocks} 个整点区块 ....", :yellow]

  #       # 保存前N-1个历史整点区块，不触发机器人策略
  #       (last_processed + 20...current_target).step(20) do |block_number|
  #         save_block_quietly(block_number)
  #       end

  #       # 保存最新的整点区块，并触发机器人策略
  #       save_block_and_trigger(current_target)

  #     else
  #       puts Paint[".... 长时间断档，缺失 #{missing_blocks} 个整点区块，补齐最近 #{INITIAL_BACKFILL_COUNT} 个 ....", :yellow]

  #       # 保存前4个历史整点区块，不触发机器人策略
  #       start_num = current_target - ((INITIAL_BACKFILL_COUNT - 1) * 20)
  #       (start_num...(current_target)).step(20) do |block_number|
  #         save_block_quietly(block_number)
  #       end

  #       # 保存最新的整点区块，并触发机器人策略
  #       save_block_and_trigger(current_target)
  #     end
  #   else
  #     Rails.logger.info ".... 尚无新的整点区块（等待下一个） ...."
  #   end
  # end

  # 安静保存区块，不触发机器人策略
  def save_block_quietly(block_number)
    return if BlockRecord.exists?(number: block_number)
    block_data = fetch_block_by_number(block_number)
    # 最多做一次备用尝试
    if block_data.nil?
      sleep 0.7
      block_data = fetch_block_by_number(block_number)
    end

    if block_data
      save_block_record(block_data)
      puts Paint[".... 【Old】 Save 【#{block_number}】 .... Time 【#{Time.now}】 ....", :blue]
    end
  end

  # 保存区块并触发机器人策略（有时间判断）
  def save_block_and_trigger(block_number)
    return if BlockRecord.exists?(number: block_number)
    puts Paint[".... Try save 【#{block_number}】 ....", :yellow]

    block_data = fetch_block_by_number(block_number)
    # 最多做一次备用尝试（符合你“尽量一次成功”的要求）
    if block_data.nil?
      sleep 0.8
      block_data = fetch_block_by_number(block_number)
    end
    return unless block_data

    # 保存区块记录
    block_record = save_block_record(block_data)
    return unless block_record

    puts Paint[".... Save 【#{block_number}】 .... Time 【#{Time.now}】 ....", :green]

    # 判断时间是否足够执行机器人策略
    if enough_time_for_transfer?(block_record.block_time)
      trigger_bot_monitoring
    else
      puts Paint[".... ⚠ 距离下一个整点区块时间不足 #{MINIMUM_TIME_FOR_TRANSFER} 秒，跳过机器人策略 ....", :red]
    end
  end

  def enough_time_for_transfer?(block_time)
    # 区块时间是以UTC存储的，转换为本地时间进行比较
    block_local_time = block_time.localtime

    # 计算这个整点区块产生后已经过去了多少秒
    elapsed_seconds = Time.current.to_i - block_local_time.to_i

    # 下一个整点区块将在60秒后产生
    remaining_seconds = 60 - elapsed_seconds

    if remaining_seconds >= MINIMUM_TIME_FOR_TRANSFER
      # puts Paint[".... ⏱ 区块 #{block_local_time.strftime('%H:%M:%S')} 已过去 #{elapsed_seconds}秒，距离下一个区块还有 #{remaining_seconds}秒，时间充足 ....", :green]
      true
    else
      puts Paint[".... ⚠ 区块 #{block_local_time.strftime('%H:%M:%S')} 已过去 #{elapsed_seconds}秒，距离下一个区块还有 #{remaining_seconds}秒，时间不足 ....", :red]
      false
    end
  end

  # 机器人策略监控
  def trigger_bot_monitoring
    latest_block = BlockRecord.last
    return unless latest_block

    active_bots = Bot.where(status: [ :running, :waiting_result ])
    return unless active_bots.any?
    puts Paint[".... #{active_bots.count} active robots, 【#{latest_block.number}】 ....", :blue]

    active_bots.each do |bot|
      begin
        bot.process_new_block(latest_block)
      rescue => e
        Rails.logger.error ".... 机器人 #{bot.id} 处理新区块时出错: #{e.message} ...."
      end
    end
  end

  def fetch_latest_block
    uri = URI("https://api.trongrid.io/wallet/getnowblock")
    response = Net::HTTP.get_response(uri)
    return unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  rescue => e
    Rails.logger.error ".... 获取最新区块失败: #{e.message} ...."
    nil
  end

  def fetch_block_by_number(num)
    url = URI("https://api.trongrid.io/wallet/getblockbynum")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request["accept"] = "application/json"
    request["content-type"] = "application/json"
    request["TRON-PRO-API-KEY"] = Rails.application.credentials.dig(:tron_grid_api_key)
    request.body = { num: num }.to_json

    response = http.request(request)
    return unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  rescue => e
    Rails.logger.error ".... 获取区块 #{num} 失败: #{e.message} ...."
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
    Rails.logger.error ".... 保存区块记录失败: #{e.message} ...."
    nil
  end
end
