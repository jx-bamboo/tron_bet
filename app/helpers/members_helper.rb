module MembersHelper
  # 策略徽章样式
  def strategy_badge_class(strategy)
    case strategy
    when "zl2"
      "zl2"
    when "zl3"
      "zl3"
    when "zl4"
      "zl4"
    when "zl5"
      "zl5"
    when "zl6"
      "zl6"
    when "zl7"
      "zl7"
    when "zl5_8"
      "zl5_8"
    when "zl7_9"
      "zl7_9"
    else
      "bg-secondary"
    end
  end

  # 失败计数器样式
  def failure_counter_class(failed_times)
    if failed_times <= 3
      "low"
    elsif failed_times <= 6
      "medium"
    else
      "high"
    end
  end

  # 当前方向样式
  def current_parity_class(parity)
    case parity&.to_s
    when "single"
      "text-danger" # 单数用红色
    when "double"
      "text-success" # 双数用绿色
    else
      "text-secondary"
    end
  end

  # 状态徽章
  def status_badge(member)
    if member.active?
      content_tag(:span, "运行中", class: "badge bg-success")
    else
      content_tag(:span, "已停止", class: "badge bg-secondary")
    end
  end

  def bot_status_text(status)
    case status
    when "stopped"
      content_tag(:span, "已停止", class: "badge bg-danger")
    when "running"
      content_tag(:span, "运行中", class: "badge bg-success")
    when "waiting_result"
      content_tag(:span, "等待结果", class: "badge bg-info")
    when "paused"
      content_tag(:span, "暂停中", class: "badge bg-warning")
    else
      content_tag(:span, "未启用", class: "badge bg-secondary")
    end
  end

  # 格式化时间
  def format_time(time)
    time&.strftime("%Y-%m-%d %H:%M") || "无"
  end

  # 下注方向样式
  def bet_parity_badge_class(parity)
    case parity&.to_s
    when "0", "double"
      "bg-primary-subtle text-primary"  # 双数
    when "1", "single"
      "bg-warning-subtle text-warning"  # 单数
    else
      "bg-secondary-subtle text-secondary"
    end
  end

  # 下注方向文本
  def bet_parity_text(parity)
    case parity&.to_s
    when "0", "double"
      "双"
    when "1", "single"
      "单"
    else
      "未知"
    end
  end

  # 结果方向样式
  def result_parity_badge_class(parity)
    case parity&.to_s
    when "0", "double"
      "bg-info-subtle text-info"  # 双数结果
    when "1", "single"
      "bg-danger-subtle text-danger"  # 单数结果
    else
      "bg-secondary-subtle text-secondary"
    end
  end

  # 结果方向文本
  def result_parity_text(parity)
    case parity&.to_s
    when "0", "double"
      "双"
    when "1", "single"
      "单"
    else
      "未知"
    end
  end

  # 截断交易ID显示
  def truncate_transaction_id(transaction_id, length: 4)
    return "-" if transaction_id.blank?

    if transaction_id.length > (length * 2 + 3)
      "#{transaction_id[0...length]}...#{transaction_id[-length..]}"
    else
      transaction_id
    end
  end

  # 下注状态文本
  def bet_status_text(bet_record)
    return "等待中" if bet_record.success.nil?
    bet_record.success ? "成功" : "失败"
  end

  # 下注状态样式
  def bet_status_class(bet_record)
    return "secondary" if bet_record.success.nil?
    bet_record.success ? "success" : "danger"
  end

  def get_strategy_text(strategy)
    case strategy
    when "zl2"
      "斩龙2"
    when "zl3"
      "斩龙3"
    when "zl4"
      "斩龙4"
    when "zl5"
      "斩龙5"
    when "zl6"
      "斩龙6"
    when "zl7"
      "斩龙7"
    when "zl2_3"
      "斩龙2～3"
    when "zl5_8"
      "斩龙5~8"
    when "zl7_8"
      "斩龙7～8"
    when "zl7_9"
      "斩龙7~9"
    when "zl2_3_m"
      "斩龙2～3无限版(50,100)"
    when "zl3_4_m"
      "斩龙3～4无限版(50,100)"
    when "zl2_p"
      "斩龙2平推版(50)"
    when "zl3_p"
      "斩龙3平推版(50)"
    when "zl4_p"
      "斩龙4平推版(50)"
    when "sl2"
      "顺龙2平推无限版(50)"
    end
  end
end
