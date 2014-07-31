class Tenant < ActiveRecord::Base
  attr_accessible :name
  validates :name, uniqueness: true
  has_one :subscription
  has_one :access_restriction
end
