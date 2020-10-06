class ChangeColumnOfGeneralSetting < ActiveRecord::Migration[5.1]
  def change
  	change_column :general_settings, :cost_calculator_url, :text
  end
end
