class AccessRestriction < ActiveRecord::Base
  # attr_accessible :title, :body
  has_one :tenant
end
