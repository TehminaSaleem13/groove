class OrderShipping < ActiveRecord::Base
  belongs_to :order
  attr_accessible :city, :country, :description, :email, :firstname,
                  :lastname, :postcode, :region, :streetaddress1, :streetaddress2

  #===========================================================================================
  #please update the delete_orders library if adding before_destroy or after_destroy callback
  # or adding dependent destroy for associated models
  #===========================================================================================
end
