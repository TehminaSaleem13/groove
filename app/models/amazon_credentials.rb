class AmazonCredentials < ActiveRecord::Base

  attr_accessible :marketplace_id, :merchant_id, :import_products, :import_images, :show_product_weight, :show_shipping_weight, :mws_auth_token

  validates_presence_of :marketplace_id, :merchant_id
  before_save :check_mws_auth_token

  belongs_to :store

  def check_mws_auth_token
  	self.mws_auth_token = "" if self.mws_auth_token.nil?
  	self.mws_auth_token = "" if ["null", "undefined"].include?(self.mws_auth_token)
  end
end
