class AddIsHapticsOptionToGeneralSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :is_haptics_option, :boolean, default: false
  end
end
