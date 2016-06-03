class AddShowPrimaryBinLocInBarcodeslipColumnToGeneralSettings < ActiveRecord::Migration
  def change
    add_column :general_settings, :show_primary_bin_loc_in_barcodeslip, :boolean, :default => false
  end
end
