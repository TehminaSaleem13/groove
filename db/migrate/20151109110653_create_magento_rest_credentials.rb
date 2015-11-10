class CreateMagentoRestCredentials < ActiveRecord::Migration
  def change
    create_table :magento_rest_credentials do |t|
      t.integer :store_id
      t.string :host
      t.string :api_key
      t.string :api_secret
      t.boolean :import_images
      t.boolean :import_categories

      t.timestamps
    end
  end
end
