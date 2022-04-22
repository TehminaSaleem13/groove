class PackingCam < ApplicationRecord
  belongs_to :order
  belongs_to :user
  belongs_to :order_item, optional: true

  validates_presence_of :url
end
