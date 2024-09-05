# frozen_string_literal: true

class ColumnPreference < ApplicationRecord
  belongs_to :user,  optional: true
  # attr_accessible :identifier, :theads
  serialize :theads
end
