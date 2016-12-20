class AddFieldToGeneralSetting < ActiveRecord::Migration
  def change
  	add_column :general_settings, :cost_calculator_url, :string
  end
end
