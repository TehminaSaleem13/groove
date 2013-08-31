class EbayCredentials < ActiveRecord::Base
  
  attr_accessible :app_id, :auth_token, :cert_id, :dev_id, :productapp_id, :productauth_token, :productcert_id, 
  :productdev_id, :import_products, :import_images 

  validates_presence_of :app_id, :auth_token, :cert_id, :dev_id, :productapp_id, :productauth_token, :productcert_id, 
  :productdev_id
  belongs_to :store

end
