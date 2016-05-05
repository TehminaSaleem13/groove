class MagentoCredentials < ActiveRecord::Base

  attr_accessible :host, :password, :username, :api_key, :import_products, :import_images

  validates_presence_of :host, :username, :api_key

  belongs_to :store

  before_save :check_value_of_status_to_update

  private

    def check_value_of_status_to_update
      self.status_to_update = "complete" if [nil, "", "null", "undefined"].include?(self.status_to_update)
    end
end
