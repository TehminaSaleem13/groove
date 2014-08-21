class AllowMagentoPasswordToBeNull < ActiveRecord::Migration
  def up
    change_column_null(:magento_credentials, :password, true)
    change_column_default(:magento_credentials, :password, '')
  end

  def down
    change_column_null(:magento_credentials, :password, false)
    change_column_default(:magento_credentials, :password, nil)
  end
end
