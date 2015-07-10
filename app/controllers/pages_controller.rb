class PagesController < ApplicationController

  def index
    harvest = Harvest.client(subdomain: ENV["HARVEST_SUBDOMAIN"],
                             username: ENV["HARVEST_USERNAME"],
                             password: ENV["HARVEST_PASSWORD"])
    today = Date.today
    # If it's after midnight, it's yesterday. Also, hour is private.
    today -= 1.day if Time.now.hour <= 7
    today += params[:days].to_i.days

    monday = today
    monday -= 1.day until monday.monday?
    @days_and_hours_this_week = (monday..today).map do |date|
      harvest_time_data = harvest.time.all(date)
      total_hours_this_date = harvest_time_data.map{|x| x[:hours] }.inject(:+)
      { date: date,
        hours: (harvest_time_data.map{ |x| {x[:project] => x[:hours]} } <<
          { "Total" => total_hours_this_date || 0 }).
          inject(:merge)
      }
    end

    @days_and_hours_this_week.each do |hash|
      hash.values.each do |value|
        value ||= 0
      end
    end

    hours_this_week = 0
    @days_and_hours_this_week.each do |hash|
      hours_this_day = hash[:hours]["Total"]
      hours_this_week += hours_this_day if hours_this_day.respond_to?(:+)
    end

    @hours_today = @days_and_hours_this_week.last[:hours]["Total"]
    @hours_today ||= 0

    hours_owed =  (8 * (@days_and_hours_this_week.length - 1)) -
      (hours_this_week - @hours_today)

    @hours_needed_today = 40 - hours_this_week
    unless today.friday? || today.sunday? || today.saturday?
      if @hours_needed_today > (8 + hours_owed)
        @hours_needed_today = (8 + hours_owed)
      end
      @hours_needed_today -= @hours_today
    end
    @hours_needed_today = 0 if @hours_needed_today < 0

    params[:days] = params[:days].to_i

  end

  def sky_color_test
    @times = (0..200).to_a.map { |x| x / (200.0 / 24) }
  end

end
