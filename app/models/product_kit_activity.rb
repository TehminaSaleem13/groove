class ProductKitActivity < ActiveRecord::Base
  attr_accessible :activity_message, :activity_type, :product_id, :username, :acknowledged
end
