class AddExportItemSettingToGeneralSetting < ActiveRecord::Migration
  def change
    add_column :general_settings, :export_items, :string, :default =>'disabled'
  end
end
