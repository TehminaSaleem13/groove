# frozen_string_literal: true

class ToteSet < ActiveRecord::Base
  # attr_accessible :name, :max_totes, :number

  has_many :totes
end
