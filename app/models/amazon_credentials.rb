class AmazonCredentials < ActiveRecord::Base
  
  attr_accessible :access_key_id, :app_name, :app_version, :marketplace_id, :merchant_id, :secret_access_key,
  :productaccess_key_id, :productapp_name, :productapp_version, :productmarketplace_id, :productmerchant_id, 
  :productsecret_access_key, :import_products, :import_images

  validates_presence_of :access_key_id, :app_name, :app_version, :marketplace_id, :merchant_id, :secret_access_key,
  :productaccess_key_id, :productapp_name, :productapp_version, :productmarketplace_id, :productmerchant_id, 
  :productsecret_access_key

  belongs_to :store

end
