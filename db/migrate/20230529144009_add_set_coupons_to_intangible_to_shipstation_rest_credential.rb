class AddSetCouponsToIntangibleToShipstationRestCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :set_coupons_to_intangible, :boolean, default: false
  end
end
