class CreateShoplineCredentials < ActiveRecord::Migration[5.1]
  def change
    create_table :shopline_credentials do |t|
      t.string :shop_name
      t.text :access_token
      t.integer :store_id
      t.datetime :last_imported_at
      t.string :shopline_status, default: "open"
      t.boolean :import_inventory_qoh, default: false
      t.boolean :import_updated_sku, default: false
      t.string :updated_sku_handling, default: "add_to_existing"
      t.string :generating_barcodes, default: "do_not_generate"
      t.string :modified_barcode_handling, default: "add_to_existing"
      t.boolean :shipped_status, default: false
      t.boolean :unshipped_status, default: false
      t.boolean :on_hold_status, default: false
      t.boolean :partial_status, default: false
      t.boolean :import_fulfilled_having_tracking, default: false
      t.boolean :import_variant_names, default: false
      t.bigint :push_inv_location_id
      t.bigint :pull_inv_location_id
      t.boolean :pull_combined_qoh, default: false
      t.boolean :fix_all_product_images, default: false
      t.datetime :product_last_import

      t.timestamps
    end

    add_column :access_restrictions, :allow_shopline_inv_push, :boolean, default: false
    add_column :sync_options, :sync_with_shopline, :boolean, default: false
    add_column :sync_options, :shopline_product_variant_id, :string
    add_column :sync_options, :shopline_inventory_item_id, :string
  end
end
