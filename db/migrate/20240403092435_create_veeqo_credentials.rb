class CreateVeeqoCredentials < ActiveRecord::Migration[5.1]
  def change
    create_table :veeqo_credentials do |t|
      t.string :api_key
      t.integer :store_id
      t.datetime :last_imported_at
      t.boolean :shipped_status, default: false
      t.boolean :awaiting_amazon_fulfillment_status, default: false
      t.boolean :awaiting_fulfillment_status, default: false
      t.boolean :import_shipped_having_tracking, default: false
      t.boolean :gen_barcode_from_sku, default: false
      t.boolean :allow_duplicate_order, default: false
      t.boolean :shall_import_internal_notes, default: false
      t.boolean :shall_import_customer_notes, default: false
      t.integer :order_import_range_days, default: 30

      t.timestamps
    end
  end
end
