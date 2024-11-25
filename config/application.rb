require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Coesfcjp
  class Application < Rails::Application
    config.generators do |generate|
      generate.assets false
      generate.helper false
      generate.test_framework :test_unit, fixture: false, test: false
    end
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0


    # For PDFs
    config.assets.precompile += %w(imagen.png)
    config.assets.precompile << 'pdf.scss'

    # config.middleware.use ActionDispatch::Cookies
    # config.middleware.use ActionDispatch::Session::CookieStore


    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '*.{rb,yml}')]
    config.i18n.default_locale = :es
    config.time_zone = "Caracas"
    # config.assets.initialize_on_precompile = false
    config.active_job.queue_adapter = :delayed_job

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    
    # config.eager_load_paths << Rails.root.join("extras")
  end
end

# Load dotenv only in development or test environment
if ['development'].include? ENV['RAILS_ENV']
  Dotenv::Railtie.load
end
HOSTNAME = ENV['HOSTNAME']
