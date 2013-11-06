class OrderExceptions < ActiveRecord::Base
  belongs_to :user
  attr_accessible :description, :reason
end
