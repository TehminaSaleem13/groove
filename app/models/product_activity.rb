class ProductActivity < ActiveRecord::Base
  # attr_accessible :title, :body
  belongs_to :product
  belongs_to :user, optional: true
  # attr_accessible :action, :activitytime, :acknowledged
end
