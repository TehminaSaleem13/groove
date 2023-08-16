class ShippingLabel < ApplicationRecord
  belongs_to :order, optional: true
end
