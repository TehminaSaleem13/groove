class AddColumnToShippingEasyCredentials < ActiveRecord::Migration
  def change
    add_column :shipping_easy_credentials, :last_imported_at, :datetime
  end
end
