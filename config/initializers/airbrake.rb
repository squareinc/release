if ENV['ERRBIT_API_KEY'].present?
  errbit_url = Plek.find('errbit')
  #
  Airbrake.configure do |config|
    config.project_key = ENV['ERRBIT_API_KEY']
    config.project_id = 1 # dummy, not used in Errbit
    config.host = errbit_url
    config.environment = ENV['ERRBIT_ENVIRONMENT_NAME']
  end
end
