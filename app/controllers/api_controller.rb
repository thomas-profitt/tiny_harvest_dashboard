require 'pp'

class ApiController < ApplicationController

  # GET
  def harvest_data
    harvest = Harvest.client(subdomain: ENV["HARVEST_SUBDOMAIN"],
                             username: ENV["HARVEST_USERNAME"],
                             password: ENV["HARVEST_PASSWORD"])

    today = Date.today
    today -= 1.day if its_really_tomorrow
    today += params[:days].to_i.days
    human_today =
      today.to_time.strftime("%a, %b #{today.to_time.day.ordinalize}")

    sunday = today
    sunday -= 1.day until sunday.sunday?
    days_and_hours_this_week = (sunday..today).map do |date|
      harvest_time_data = harvest.time.all(date)
      total_hours_this_date = harvest_time_data.map{|x| x[:hours] }.inject(:+)
      { date: date,
        hours: (harvest_time_data.map{ |x| {x[:project] => x[:hours]} } << { "Total" => total_hours_this_date || 0 }).inject { |memo, el| memo.merge(el) { |key, oldval, newval| oldval + newval } }
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
      (8 * (days_and_hours_this_week.length - 2)) -
      (hours_this_week - hours_today)

    # hours_needed_today now reflects how many hours total were needed today,
    # not counting hours logged today.
    # Later, hours_today is subtracted from it.
    hours_needed_today = 40 - (hours_this_week - hours_today)
    unless today.friday? || today.saturday?
      if hours_needed_today > (8 + hours_owed)
        hours_needed_today = (8 + hours_owed)
      end
    end
    hours_needed_today -= hours_today
    hours_needed_today = 0 if hours_needed_today < 0

    if hours_needed_today > 0
      if params[:days] && params[:days].to_i != 0
        # If it's not today, a done_at estimate means nothing.
        done_at = "-N/A-"
      else
        done_at = (Time.now + hours_needed_today.hours).strftime("%02l:%M")
      end
    else
      done_at = "DONE!"
    end

    # FIXME magic
    projects_and_hours_this_week =
      Hash[days_and_hours_this_week.map { |x| x[:hours] }.inject { |memo, el| memo.merge(el) { |k, old_v, new_v| old_v + new_v }}.sort_by { |k, v| v }.each { |a| a[-1] = hours_to_human a[-1] }.reject { |a| a.first == "Total" }.reverse]

    case params[:format]
    when "json"
      render json: {
        human_today: human_today,
        hours_today: hours_to_human(hours_today),
        hours_needed_today: hours_to_human(hours_needed_today),
        done_at: done_at,
        projects_and_hours_this_week: projects_and_hours_this_week
      }
    when "txt"
      human_projects_and_hours_this_week = ""
      projects_and_hours_this_week.each do |k, v|
        human_projects_and_hours_this_week << "\n  #{v} #{k}"
      end
      render plain: [
        "#{human_today}",
        "  #{hours_to_human(hours_today)} today",
        "  #{hours_to_human(hours_needed_today)} to go",
        "  Done at #{done_at}",
        "#{human_projects_and_hours_this_week}"].join("\n")
    end
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

    request_location = request.location
    Rails.logger.info "request_location: " << request_location.inspect

    if request_location.respond_to?(:latitude) && request_location.respond_to?(:longitude) &&
    !(request_location.latitude == 0.0 || request_location.longitude == 0.0)
      solar_day_latitude = request_location.latitude
      solar_day_longitude = request_location.longitude
    else
      solar_day_latitude = ENV["DEFAULT_LATITUDE"].to_f
      solar_day_longitude = ENV["DEFAULT_LONGITUDE"].to_f
      Rails.logger.info "request_location invalid; using default latitude/longitude of #{solar_day_latitude}/#{solar_day_longitude}"
    end

    today = SolarDay.create_or_update_today_for_date_and_longitude_and_latitude(
      (its_really_tomorrow ? Date.yesterday : Date.today),
      solar_day_latitude,
      solar_day_longitude
    )

    if today
      Rails.logger.debug "hours: #{hours}"
      Rails.logger.debug "today.sunrise_at: #{today.sunrise_at.inspect}"
      Rails.logger.debug "today.sunrise_at_hours: #{today.sunrise_at_hours}"
      Rails.logger.debug "today.solar_noon_at: #{today.solar_noon_at.inspect}"
      Rails.logger.debug "today.solar_noon_at_hours: #{today.solar_noon_at_hours}"
      Rails.logger.debug "today.sunset_at: #{today.sunset_at.inspect}"
      Rails.logger.debug "today.sunset_at_hours: #{today.sunset_at_hours}"
    end

    sunrise_at_hours = today ? today.sunrise_at_hours : 5
    solar_noon_at_hours = today ? today.solar_noon_at_hours : 12
    sunset_at_hours = today ? today.sunset_at_hours : 20

    stages = [
      {
        hours: 0..sunrise_at_hours,
        color: {
          red: 2,
          green: 10,
          blue: 20
        }
      },
      {
        hours: sunrise_at_hours..(sunrise_at_hours + 1),
        color: {
          red: 2..114,
          green: 10..161,
          blue: 20..183,
        }
      },
      {
        hours: sunrise_at_hours..solar_noon_at_hours,
        color: {
          red: 114..138,
          green: 161..191,
          blue: 183..213,
        }
      },
      {
        hours: (solar_noon_at_hours)..(solar_noon_at_hours + 3),
        color: {
          red: 138..108,
          green: 191..153,
          blue: 213..175
        }
      },
      {
        hours: (solar_noon_at_hours + 3)..(sunset_at_hours - 1),
        color: {
          red: 108..104,
          green: 153..160,
          blue: 175..138
        }
      },
      {
        hours: (sunset_at_hours - 1)..(sunset_at_hours + 0.1),
        color: {
          red: 104..255,
          green: 160..182,
          blue: 138..116
        }
      },
      {
        hours: (sunset_at_hours + 0.1)..(sunset_at_hours + 0.25),
        color: {
          red: 255..209,
          green: 182..195,
          blue: 116..185
        }
      },
      {
        hours: (sunset_at_hours + 0.25)..(sunset_at_hours + 0.5),
        color: {
          red: 209..126,
          green: 195..109,
          blue: 185..148
        }
      },
      {
        hours: (sunset_at_hours + 0.5)..(23),
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

    Rails.logger.debug "stages:\n#{stages.pretty_inspect}"

    # Default colors
    red = 13
    green = 30
    blue = 38

    stages.each do |stage|
      if stage[:hours].include? hours
        color = stage[:color]
        red, green, blue = color[:red], color[:green], color[:blue]

        if red.class == Range
          red = NumericRangeUtils.shift_proportions(
            hours, stage[:hours], red)
        end
        if green.class == Range
          green = NumericRangeUtils.shift_proportions(
            hours, stage[:hours], green)
        end
        if blue.class == Range
          blue = NumericRangeUtils.shift_proportions(
            hours, stage[:hours], blue)
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

end

