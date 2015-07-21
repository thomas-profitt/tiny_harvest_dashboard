Rails.application.routes.draw do
  root 'pages#index'

  get 'sky_color_test' => "pages#sky_color_test"

  get 'api/sky_color'
  get 'api/harvest_data'
end
