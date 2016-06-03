class AddColumnPushTrackingNumberToMagentoCredentials < ActiveRecord::Migration
  def change
    add_column :magento_credentials, :push_tracking_number, :boolean, :default => false
  end
end
