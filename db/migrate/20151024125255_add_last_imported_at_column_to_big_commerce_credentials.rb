class AddLastImportedAtColumnToBigCommerceCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :big_commerce_credentials, :last_imported_at, :datetime
  end
end
