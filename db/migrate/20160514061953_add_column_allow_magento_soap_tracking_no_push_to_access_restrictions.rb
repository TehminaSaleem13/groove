class AddColumnAllowMagentoSoapTrackingNoPushToAccessRestrictions < ActiveRecord::Migration[5.1]
  def change
    add_column :access_restrictions, :allow_magento_soap_tracking_no_push, :boolean, :default => false
  end
end
