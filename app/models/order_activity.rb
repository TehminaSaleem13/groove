class OrderActivity< ActiveRecord::Base
  belongs_to :order
  belongs_to :user
  attr_accessible :action, :activitytime
end
