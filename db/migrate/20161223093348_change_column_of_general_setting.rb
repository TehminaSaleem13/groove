class ChangeColumnOfGeneralSetting < ActiveRecord::Migration
  def change
  	change_column :general_settings, :cost_calculator_url, :text
  end
end
