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

    # hours_needed_today now reflects how many hours total were needed today,
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

    if params[:days] && params[:days].to_i != 0
      # If it's not today, a done_at estimate means nothing.
      done_at = "-N/A-"
    elsif hours_needed_today > 0
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

    stages = [
      {
        hours: 0..5,
        color: {
          red: 2,
          green: 10,
          blue: 20
        }
      },
      {
        hours: 5..12,
        color: {
          red: 2..138,
          green: 10..191,
          blue: 20..213,
        }
      },
      {
        hours: 12..15,
        color: {
          red: 138..108,
          green: 191..153,
          blue: 213..175
        }
      },
      {
        hours: 15..19,
        color: {
          red: 108..104,
          green: 153..160,
          blue: 175..138
        }
      },
      {
        hours: 19..20,
        color: {
          red: 104..255,
          green: 160..182,
          blue: 138..116
        }
      },
      {
        hours: 20..20.25,
        color: {
          red: 255..209,
          green: 182..195,
          blue: 116..185
        }
      },
      {
        hours: 20.25..20.5,
        color: {
          red: 209..126,
          green: 195..109,
          blue: 185..148
        }
      },
      {
        hours: 20.5..23,
        color: {
          red: 126..2,
          green: 109..10,
          blue: 148..20
        }
      },
      {
        hours: 23..24,
        color: {
          red: 2,
          green: 10,
          blue: 20
        }
      }
    ]

    # Default colors
    red = 13
    green = 30
    blue = 38

    stages.each do |stage|
      if stage[:hours].include? hours
        color = stage[:color]
        red, green, blue = color[:red], color[:green], color[:blue]

        if red.class == Range
          red = shift_proportions(hours, stage[:hours], red)
        end
        if green.class == Range
          green = shift_proportions(hours, stage[:hours], green)
        end
        if blue.class == Range
          blue = shift_proportions(hours, stage[:hours], blue)
        end

        break
      end
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

    value_from_zero / range_from_zero.last.to_f
  end

  def shift_range(range, shift)
    (range.first + shift)..(range.last + shift)
  end

  # value is to old_range as the returned value is to new_range, eg.
  # shift_proportions(5, 0..10, 0..100) #=> 50
  # shift_proportions(5.0, 0..-10, 0..100) #=> -50.0
  def shift_proportions(value, old_range, new_range)
    ret = range_value_from_position(new_range, range_position_from_value(old_range, value))
    ret = ret.to_i if value.class == Fixnum
    ret
  end

end

