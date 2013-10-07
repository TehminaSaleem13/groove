class RemoveColumnFromEbayCredentials < ActiveRecord::Migration
  def up
    remove_column :ebay_credentials, :dev_id
  end

  def down
    add_column :ebay_credentials, :dev_id, :string
  end
end
