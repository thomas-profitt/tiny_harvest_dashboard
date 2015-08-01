class ApiController < ApplicationController

  # GET
  def harvest_data
    harvest = Harvest.client(subdomain: ENV["HARVEST_SUBDOMAIN"],
                             username: ENV["HARVEST_USERNAME"],
                             password: ENV["HARVEST_PASSWORD"])

    today = Date.today
    today -= 1.day if its_really_tomorrow
    today += params[:days].to_i.days
    human_today = today.to_time.strftime("%A, #{today.to_time.day.ordinalize}")

    monday = today
    monday -= 1.day until monday.monday?
    days_and_hours_this_week = (monday..today).map do |date|
      harvest_time_data = harvest.time.all(date)
      total_hours_this_date = harvest_time_data.map{|x| x[:hours] }.inject(:+)
      { date: date,
        hours: (harvest_time_data.map{ |x| {x[:project] => x[:hours]} } << { "Total" => total_hours_this_date || 0 }).inject(:merge)
      }
    end

    days_and_hours_this_week.each do |hash|
      hash.values.each do |value|
        value ||= 0
      end
    end

    hours_this_week = 0
    days_and_hours_this_week.each do |hash|
      hours_this_day = hash[:hours]["Total"]
      hours_this_week += hours_this_day if hours_this_day.respond_to?(:+)
    end

    hours_today = days_and_hours_this_week.last[:hours]["Total"]
    hours_today ||= 0

    hours_owed =
      (8 * (days_and_hours_this_week.length - 1)) -
      (hours_this_week - hours_today)


    # hours_needed_today now reflects how many hours, total, were needed today,
    # not counting hours logged today.
    # Later, hours_today is subtracted from it.
    hours_needed_today = 40 - (hours_this_week - hours_today)
    unless today.friday? || today.sunday? || today.saturday?
      if hours_needed_today > (8 + hours_owed)
        hours_needed_today = (8 + hours_owed)
      end
    end
    hours_needed_today -= hours_today
    hours_needed_today = 0 if hours_needed_today < 0

    if hours_needed_today > 0
      done_at = (Time.now + hours_needed_today.hours).strftime("%02l:%M")
    else
      done_at = "DONE!"
    end

    # FIXME magic
    projects_and_hours_this_week =
      Hash[days_and_hours_this_week.map { |x| x[:hours] }.inject { |memo, el| memo.merge(el) { |k, old_v, new_v| old_v + new_v }}.sort_by { |k, v| v }.each { |a| a[-1] = hours_to_human a[-1] }.reject { |a| a.first == "Total" }.reverse]

    render json: {
      human_today: human_today,
      hours_today: hours_to_human(hours_today),
      hours_needed_today: hours_to_human(hours_needed_today),
      done_at: done_at,
      projects_and_hours_this_week: projects_and_hours_this_week
    }
  end

  def sky_color

    if params[:hours]
      color = sky_color_for_hours params[:hours].to_f
    else
      color = sky_color_for_hours
    end

    render json: {sky_color: color}.to_json

  end


  private ######################################################################

  def its_really_tomorrow
    Time.now.hour < 7
  end

  def sky_color_for_hours(hours = Time.now.hour + (Time.now.min / 60.0) + (Time.now.sec / 3600.0))
    red = 13
    green = 30
    blue = 38

    case hours
    when 0..5, 23..24
      red = 2
      green = 10
      blue = 20
    when 5..12
      red =
        range_value_from_position(
          2..138, range_position_from_value(5..12, hours))
      green =
        range_value_from_position(
          10..191, range_position_from_value(5..12, hours))
      blue =
        range_value_from_position(
          20..213, range_position_from_value(5..12, hours))
    when 12..15
      red =
        range_value_from_position(
          138..108, range_position_from_value(12..15, hours))
      green =
        range_value_from_position(
          191..153, range_position_from_value(12..15, hours))
      blue =
        range_value_from_position(
          213..175, range_position_from_value(12..15, hours))
   when 15..19
      red =
        range_value_from_position(
          108..104, range_position_from_value(15..19, hours))
      green =
        range_value_from_position(
          153..160, range_position_from_value(15..19, hours))
      blue =
        range_value_from_position(
          175..138, range_position_from_value(15..19, hours))
    when 19..20
      red =
        range_value_from_position(
          104..255, range_position_from_value(19..20, hours))
      green =
        range_value_from_position(
          160..182, range_position_from_value(19..20, hours))
      blue =
        range_value_from_position(
          138..116, range_position_from_value(19..20, hours))
    when 20..20.25
      red =
        range_value_from_position(
          255..209, range_position_from_value(20..20.25, hours))
      green =
        range_value_from_position(
          182..195, range_position_from_value(20..20.25, hours))
      blue =
        range_value_from_position(
          116..185, range_position_from_value(20..20.25, hours))
    when 20.25..20.5
      red =
        range_value_from_position(
          209..126, range_position_from_value(20.25..20.5, hours))
      green =
        range_value_from_position(
          195..109, range_position_from_value(20.25..20.5, hours))
      blue =
        range_value_from_position(
          185..148, range_position_from_value(20.25..20.5, hours))
    when 20.5..23
      red =
        range_value_from_position(
          126..2, range_position_from_value(20.5..23, hours))
      green =
        range_value_from_position(
          109..10, range_position_from_value(20.5..23, hours))
      blue =
        range_value_from_position(
          148..20, range_position_from_value(20.5..23, hours))
    end

    color = "rgb(#{red.round},#{green.round},#{blue.round})"
    return color
  end

  def hours_to_human(hours)
    hours_negative = (hours < 0)
    hours = -hours if hours_negative
    ret = sprintf "%02i:%02i", hours, (60 * (hours - hours.to_i)).round
    ret = "-" << ret if hours_negative

    ret
  end

  def range_value_from_position(range, position)
    range_from_zero = shift_range(range, -range.first)

    (range_from_zero.last * position) + range.first
  end

  def range_position_from_value(range, value)
    value_from_zero = value - range.first
    range_from_zero = shift_range range, -range.first

    value_from_zero / range_from_zero.last
  end

  def shift_range(range, shift)
    (range.first + shift)..(range.last + shift)
  end

end
