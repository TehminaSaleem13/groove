class AddColumnToMagentoCreds < ActiveRecord::Migration
  def change
  	add_column :magento_credentials, :updated_patch, :boolean, :default => false
  end
end
