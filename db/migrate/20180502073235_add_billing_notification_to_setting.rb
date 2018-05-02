class AddBillingNotificationToSetting < ActiveRecord::Migration
  def change
  	add_column :general_settings, :email_address_for_billing_notification, :string
  end
end
