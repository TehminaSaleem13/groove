# frozen_string_literal: true

class ProductActivity < ActiveRecord::Base
  # attr_accessible :title, :body
  belongs_to :product
  belongs_to :user
  # attr_accessible :action, :activitytime, :acknowledged
end
