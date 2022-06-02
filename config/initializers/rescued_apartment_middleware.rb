class TenantMiddleware < Apartment::Elevators::Subdomain
  def call(env)
    if (env['SERVER_NAME'].include? 'ngrok')
      env['SERVER_NAME'] = 'gp55.localpackerapi.com'
      env['REQUEST_URI'] = 'http://gp55.localpackerapi.com'
      env['HTTP_HOST'] = 'gp55.localpackerapi.com'
    end

    request = Rack::Request.new(env)

    database = @processor.call(request)

    begin
      Apartment::Tenant.switch! database if database
    rescue Apartment::DatabaseNotFound, Apartment::SchemaNotFound
      Rails.logger.error "ERROR: Apartment Tenant not found: #{Apartment::Tenant.current.inspect}"
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
