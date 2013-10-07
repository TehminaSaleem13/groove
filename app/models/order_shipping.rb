class OrderShipping < ActiveRecord::Base
  belongs_to :order
  attr_accessible :city, :country, :description, :email, :firstname, 
  :lastname, :postcode, :region, :streetaddress1, :streetaddress2
end
