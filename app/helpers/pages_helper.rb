module PagesHelper

  def hours_to_human(hours)
    hours_negative = (hours < 0)
    hours = -hours if hours_negative
    ret = sprintf "%02i:%02i", hours, (60 * (hours - hours.to_i)).round
    ret = "-" << ret if hours_negative

    ret
  end

end
