class ColumnPreference < ActiveRecord::Base
  belongs_to :user
  attr_accessible :identifier, :theads
  serialize :theads
end
