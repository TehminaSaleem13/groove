class AddDisplayKitPartsToGeneralSettings < ActiveRecord::Migration
  def change
    add_column :general_settings, :display_kit_parts, :boolean, :default => false
  end
end
