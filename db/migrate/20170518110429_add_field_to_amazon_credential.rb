class AddFieldToAmazonCredential < ActiveRecord::Migration
  def change
  	add_column :amazon_credentials, :last_imported_at, :datetime
  end
end
