class AddColumnToShippingEasyCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :shipping_easy_credentials, :last_imported_at, :datetime
  end
end
