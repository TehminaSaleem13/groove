# frozen_string_literal: true

class OrderTag < ActiveRecord::Base
  # attr_accessible :color, :mark_place, :name, :predefined
  validates_uniqueness_of :name

  has_and_belongs_to_many :orders
  #===========================================================================================
  # please update the delete_orders library if adding before_destroy or after_destroy callback
  # or adding dependent destroy for associated models
  #===========================================================================================
end
