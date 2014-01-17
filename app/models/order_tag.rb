class OrderTag < ActiveRecord::Base
  attr_accessible :color, :mark_place, :name, :predefined
  validates_uniqueness_of :name, :color

  has_and_belongs_to_many :orders
end
