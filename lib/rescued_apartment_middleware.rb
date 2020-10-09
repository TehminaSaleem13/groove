module RescuedApartmentMiddleware
  def call(env)
    request = Rack::Request.new(env)

    database = @processor.call(request)

    begin
      Apartment::Tenant.switch! database if database
    rescue => e
      Rails.logger.error "ERROR: Apartment Tenant not found: \"#{database}\" in #{Apartment::Tenant.current.inspect}"
      Rails.logger.error e.inspect
      return [
        404,
        {"Content-Type" => "text/html"},
        [
          File.open("#{Rails.root}/public/tenant_not_found.html").read
        ]
      ]
    end

    @app.call(env)
  end
end