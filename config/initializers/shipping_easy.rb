ShippingEasy.configure do |config|
 # config.api_key = '5c587aaaba338f34c99e0b9837f24ede'
 # config.api_secret = '699e8f73a53774d36eb687e316b7327dc137f70beabcaa1e00d7ce4e9197fb96'
end


ShippingEasy::Http::Request.class_eval do

  def api_secret
    #ShippingEasy.api_secret
    params[:api_secret]
  end

  def api_key
    #ShippingEasy.api_key
    params[:api_key]
  end

end
