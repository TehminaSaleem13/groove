class AddCustomUserFieldToGeneralSetting < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :custom_user_field_one, :string
    add_column :general_settings, :custom_user_field_two, :string
  end
end
