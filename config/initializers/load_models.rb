if Rails.env == "development"
   Dir["#{Rails.root}/app/models/**/*.rb"].each { |file| require_dependency file }
end