class CreateShippingEasyCredentials < ActiveRecord::Migration
  def change
    create_table :shipping_easy_credentials do |t|
      t.integer :store_id
      t.string :api_key
      t.string :api_secret
      t.boolean :import_ready_for_shipment, default: false
      t.boolean :import_shipped, default: false
      t.boolean :gen_barcode_from_sku

      t.timestamps
    end
  end
end
