Rails.application.routes.draw do
  root 'pages#index'

  get 'sky_color_test' => "pages#sky_color_test"

  get 'api/sky_color'
  get 'api/harvest_data'
  get 'api/request_from_local_network' => 'api#request_from_local_network'
  get 'api/random_porn'
  get 'api/redirect_to_random_porn'
end
