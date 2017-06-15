class ChangeColumnDefaultField < ActiveRecord::Migration
  def up
  	change_column :ebay_credentials, :unshipped_status, :boolean, :default => true
  end

  def down
  	change_column :ebay_credentials, :unshipped_status, :boolean, :default => false
  end
end
