class OrderExceptions < ActiveRecord::Base
  belongs_to :order
  belongs_to :user
  attr_accessible :description, :reason
end
