class AddCustomFieldsToGeneralSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :custom_field_one, :string, default: 'Custom 1'
    add_column :general_settings, :custom_field_two, :string, default: 'Custom 2'
  end
end
