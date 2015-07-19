class ApiController < ApplicationController

  # GET
  def random_porn
    render json: random_porn_url.to_json
  end

  # GET
  def redirect_to_random_porn
    redirect_to random_porn_url[:file_path]
  end

  # GET
  def request_from_local_network
    render json: request_from_local_network?.to_json
  end

  # GET
  def harvest_data()
    harvest = Harvest.client(subdomain: ENV["HARVEST_SUBDOMAIN"],
                             username: ENV["HARVEST_USERNAME"],
                             password: ENV["HARVEST_PASSWORD"])
    
    today = Date.today
    today += params[:days].to_i.days

    monday = today
    monday -= 1.day until monday.monday?
    days_and_hours_this_week = (monday..today).map do |date|
      harvest_time_data = harvest.time.all(date)
      total_hours_this_date = harvest_time_data.map{|x| x[:hours] }.inject(:+)
      { date: date,
        hours: (harvest_time_data.map{ |x| {x[:project] => x[:hours]} } <<
          { "Total" => total_hours_this_date || 0 }).
          inject(:merge)
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

    hours_owed =  (8 * (days_and_hours_this_week.length - 1)) -
      (hours_this_week - hours_today)

    hours_needed_today = 40 - hours_this_week
    unless today.friday? || today.sunday? || today.saturday?
      if hours_needed_today > (8 + hours_owed)
        hours_needed_today = (8 + hours_owed)
      end
      hours_needed_today -= hours_today
    end
    hours_needed_today = 0 if hours_needed_today < 0

    done_at = nil
    if hours_needed_today > 0
      done_at = (Time.now + hours_needed_today.hours).strftime("%02l:%M")
    else
      done_at = "DONE!"
    end

    # FIXME magic
    projects_and_hours_this_week =
      Hash[days_and_hours_this_week.map { |x| x[:hours] }.inject { |memo, el| memo.merge(el) { |k, old_v, new_v| old_v + new_v }}.sort_by { |k, v| v }.each { |a| a[-1] = hours_to_human a[-1] }.reject { |a| a.first == "Total" }.reverse]

    render json: {
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

    render json: color.to_json

  end

  def sky_color_for_hours(hours = Time.now.hour + (Time.now.min / 60.0) + (Time.now.sec / 3600.0))
    hue = 200
    saturation = 50
    lightness = 10

    case hours
    when 0..5, 23..24
      lightness = 5
    when 5..12
      saturation =
        range_value_from_position(
          100..52, range_position_from_value(5..12, hours))
      lightness =
        range_value_from_position(
          5..70, range_position_from_value(5..12, hours))
    when 12..15
      saturation = 52
      lightness =
        range_value_from_position(
          70..54, range_position_from_value(12..15, hours))
    when 15..19
      hue =
        range_value_from_position(
          200..168, range_position_from_value(15..19, hours))
      saturation =
        range_value_from_position(
          50..20, range_position_from_value(15..19, hours))
      lightness =
        range_value_from_position(
          54..45, range_position_from_value(15..19, hours))
    when 19..20
      hue =
        range_value_from_position(
          40..20, range_position_from_value(19..20, hours))
      saturation =
        range_value_from_position(
          20..30, range_position_from_value(19..20, hours))
      lightness =
        range_value_from_position(
          45..40, range_position_from_value(19..20, hours))
    when 20..23
      hue =
        range_value_from_position(
          20..30, range_position_from_value(20..23, hours))
      saturation = 10
      lightness =
        range_value_from_position(
          40..5, range_position_from_value(20..23, hours))
    end

    color = "hsl(#{hue},#{saturation}%,#{lightness}%)"
    return color
  end

  private ######################################################################

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

  def random_porn_url
    tag_whitelist = []
    tag_blacklist =
      ["female", "intersex", "breasts", "pussy", "scat", "fart",
       "my_little_pony", "five_nights_at_freddy's", "blood", "mot",
       "teenage_mutant_ninja_turtles"]

    uri = URI "https://e621.net/post/show.json"

    i = 0
    already_tried = []
    result = nil
    until (result &&
    (result["tags"].split(" ") & tag_blacklist).empty? &&
    result["tags"].split(" ") & tag_whitelist == tag_whitelist &&
    !(result["file_url"].blank?) &&
    !(result["file_url"] == "/images/deleted-preview.png"))

      random_id = rand(0..600000)
      while already_tried.include? random_id
        random_id = rand(0..600000)
      end

      uri.query = URI.encode_www_form({id: random_id})

      begin
        puts "Sending request ##{i + 1}"
        result = JSON.parse Net::HTTP.get(uri)
      rescue JSON::ParserError
        result = nil
      end
      already_tried << random_id
      i += 1
    end

    if params["full"]
      return result
    else
      return result["file_url"]
    end
  end

end
