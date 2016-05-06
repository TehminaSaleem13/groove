class OrderActivity< ActiveRecord::Base
  belongs_to :order
  belongs_to :user
  attr_accessible :action, :activitytime, :acknowledged
  #===========================================================================================
  #please update the delete_orders library if adding before_destroy or after_destroy callback
  # or adding dependent destroy for associated models
  #===========================================================================================
end
