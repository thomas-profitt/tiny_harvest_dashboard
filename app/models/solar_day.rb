class SolarDay < ActiveRecord::Base

  def self.create_or_update_today_for_date_and_longitude_and_latitude(date, latitude, longitude)
    today_for_location =
      self.
        where(
          "date = ? AND latitude >= ? AND latitude <= ? AND longitude >= ? AND longitude <= ?",
          date, latitude - 5.0, latitude + 5.0, longitude - 5.0, longitude + 5.0
        ).first_or_initialize
    unless today_for_location.sunrise_at? && today_for_location.solar_noon_at? && today_for_location.sunset_at?
      sunrise_sunset_api_endpoint = "http://api.sunrise-sunset.org/json?lat=#{latitude}&lng=#{longitude}"
      Rails.logger.info "GETting " << sunrise_sunset_api_endpoint
      sunrise_sunset_response = HTTParty.get(sunrise_sunset_api_endpoint)
      if sunrise_sunset_response["status"] == "OK"
        if today_for_location.update_attributes(
          date: date,
          latitude: latitude,
          longitude: longitude,
          sunrise_at: time_from_sunrise_sunset_time_string(sunrise_sunset_response["results"]["sunrise"]),
          solar_noon_at: time_from_sunrise_sunset_time_string(sunrise_sunset_response["results"]["solar_noon"]),
          sunset_at: time_from_sunrise_sunset_time_string(sunrise_sunset_response["results"]["sunset"])
        )
          return today_for_location
        else
          return nil
        end
      else
        return nil
      end
    end
    return today_for_location
  end

  ##############################################################################

  def sunrise_at_hours localized_time = time_in_time_zone_of_location(sunrise_at)
    localized_time.hour + (localized_time.min / 60.0) + (localized_time.sec / 3600.0)
  end

  def solar_noon_at_hours
    localized_time = time_in_time_zone_of_location(solar_noon_at)
    localized_time.hour + (localized_time.min / 60.0) + (localized_time.sec / 3600.0)
  end

  def sunset_at_hours
    localized_time = time_in_time_zone_of_location(sunset_at)
    localized_time.hour + (localized_time.min / 60.0) + (localized_time.sec / 3600.0)
  end

  private ######################################################################

  def time_in_time_zone_of_location(time)
    time.in_time_zone(NearestTimeZone.to(latitude, longitude))
  end

  def self.time_from_sunrise_sunset_time_string(sunrise_sunset_time_string)
    Time.parse sunrise_sunset_time_string + " UTC"
  end

end
