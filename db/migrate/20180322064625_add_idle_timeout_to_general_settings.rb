class AddIdleTimeoutToGeneralSettings < ActiveRecord::Migration
  def change
    add_column :general_settings, :idle_timeout, :float
  end
end
