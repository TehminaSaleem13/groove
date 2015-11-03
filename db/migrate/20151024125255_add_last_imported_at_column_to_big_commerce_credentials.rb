class AddLastImportedAtColumnToBigCommerceCredentials < ActiveRecord::Migration
  def change
    add_column :big_commerce_credentials, :last_imported_at, :datetime
  end
end
