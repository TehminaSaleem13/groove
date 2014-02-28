class ColumnPreference < ActiveRecord::Base
  belongs_to :user
  attr_accessible :identifier, :order, :shown
  serialize :order
  serialize :shown
end
