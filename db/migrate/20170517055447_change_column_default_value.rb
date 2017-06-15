class ChangeColumnDefaultValue < ActiveRecord::Migration
  def up
  	change_column :amazon_credentials, :unshipped_status, :boolean, :default => true
  end

  def down
  	change_column :amazon_credentials, :unshipped_status, :boolean, :default => false
  end
end
