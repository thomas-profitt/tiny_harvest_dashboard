class PagesController < ApplicationController

  def index
  end

  def sky_color_test
    samples = 100.0
    @times = (0..samples).to_a.map { |x| x / (samples / 24) }
    Rails.logger.debug "times: " << @times.inspect
  end

end
