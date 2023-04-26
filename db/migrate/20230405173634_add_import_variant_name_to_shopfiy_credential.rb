class AddImportVariantNameToShopfiyCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shopify_credentials, :import_variant_names, :boolean, default: false
  end
end
