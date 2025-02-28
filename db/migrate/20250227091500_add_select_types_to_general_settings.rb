class AddSelectTypesToGeneralSettings < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:general_settings, :select_types)
      add_column :general_settings, :select_types, :json, null: false
    end
  end
end
