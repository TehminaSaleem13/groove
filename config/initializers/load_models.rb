if Rails.env == "development"
   Dir["#{Rails.root}/app/models/**/*.rb"].each { |file| require_dependency file }
end

if defined?(WEBrick::HTTPRequest)
  WEBrick::HTTPRequest.const_set("MAX_URI_LENGTH", 10240)
end