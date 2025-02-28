class AddSelectTypesToGeneralSettings < ActiveRecord::Migration[6.0]
  def change
    add_column :general_settings, :select_types, :json, null: false
  end
end
