class RenameColumnStatus < ActiveRecord::Migration[5.1]
 	def change
    rename_column :shopify_credentials, :status, :shopify_status
    change_column :shopify_credentials, :shopify_status, :string, :default => "open"
  end
end
