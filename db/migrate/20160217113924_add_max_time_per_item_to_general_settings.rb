class AddMaxTimePerItemToGeneralSettings < ActiveRecord::Migration
  def change
    add_column :general_settings, :max_time_per_item, :integer, :default => 10
  end
end
