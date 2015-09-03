class Tenant < ActiveRecord::Base
  attr_accessible :name, :duplicate_tenant_id
  validates :name, uniqueness: true
  has_one :subscription
  has_one :access_restriction
end
