class AddCustomFieldsToGeneralSettings < ActiveRecord::Migration
  def change
    add_column :general_settings, :custom_field_one, :string
    add_column :general_settings, :custom_field_two, :string
  end
end
