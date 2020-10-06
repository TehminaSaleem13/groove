class AddColumnToMagentoCreds < ActiveRecord::Migration[5.1]
  def change
  	add_column :magento_credentials, :updated_patch, :boolean, :default => false
  end
end
