class PagesController < ApplicationController

  def index
  end

  def sky_color_test
    @times = (0..200).to_a.map { |x| x / (200.0 / 24) }
  end

end
