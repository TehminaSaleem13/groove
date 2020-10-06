class AddIdleTimeoutToGeneralSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :general_settings, :idle_timeout, :float
  end
end
