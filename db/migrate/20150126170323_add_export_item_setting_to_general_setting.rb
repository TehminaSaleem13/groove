class AddExportItemSettingToGeneralSetting < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :export_items, :string, :default =>'disabled'
  end
end
