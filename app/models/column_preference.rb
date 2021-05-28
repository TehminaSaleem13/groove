class ColumnPreference < ActiveRecord::Base
  belongs_to :user, optional: true
  #attr_accessible :identifier, :theads
  serialize :theads
end
