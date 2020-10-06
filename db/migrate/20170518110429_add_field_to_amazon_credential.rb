class AddFieldToAmazonCredential < ActiveRecord::Migration[5.1]
  def change
  	add_column :amazon_credentials, :last_imported_at, :datetime
  end
end
