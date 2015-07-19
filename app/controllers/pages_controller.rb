class PagesController < ApplicationController

  def index
    if params[:days]
      params[:days] = params[:days].to_i
    else
      params[:days] = 0
    end
  end

  def sky_color_test
    @times = (0..200).to_a.map { |x| x / (200.0 / 24) }
  end

end
