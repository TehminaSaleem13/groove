namespace :shipstation do
  desc "modify general settings and sets default product weight format as oz"
  task :import_tracking_number => :environment do
    client = Groovepacker::ShipstationRuby::Rest::Client.new(
      "2408d236b6154557bd60dd78142d031d", "a3116facdddc49d38e247d4fc8bc6440")
    
    response = client.get_tracking_number("17918")
    puts response.inspect
  end
end