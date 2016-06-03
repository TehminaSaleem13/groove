class MagentoRestCredential < ActiveRecord::Base
  attr_accessible :api_key, :api_secret, :host, :import_categories, :import_images, :store_id, :access_token
  belongs_to :store

  before_save :check_api_key_and_secret_values

  private
    def check_api_key_and_secret_values
      self.api_key = nil if [nil, "", "null", "undefined"].include?(self.api_key)
      self.api_secret = nil if [nil, "", "null", "undefined"].include?(self.api_secret)
    end
end
