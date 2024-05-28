class ShipstationLabelData < ApplicationRecord
  belongs_to :order

  serialize :content, JSON
end
