class EbayCredentials < ActiveRecord::Base
  
  attr_accessible :auth_token, :productauth_token, :import_products, :import_images, :ebay_auth_expiration

  def get_signinurl
	require 'eBayAPI'
  
	@eBay = EBay::API.new(self.auth_token, 
	    ENV['EBAY_DEV_ID'], ENV['EBAY_APP_ID'], 
	    ENV['EBAY_CERT_ID'], :sandbox=>true)

	@signinurl = "https://signin.sandbox.ebay.com/ws/eBayISAPI.dll?SignIn&runame="+
	              "Navaratan_Techn-Navarata-607d-4-ltqij&SessID="+session_id
  end

  def get_token

  end
end
