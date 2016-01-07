class AddCustomFieldsToGeneralSettings < ActiveRecord::Migration
  def change
    add_column :general_settings, :custom_field_one, :string, default: 'Custom 1'
    add_column :general_settings, :custom_field_two, :string, default: 'Custom 2'
  end
end
