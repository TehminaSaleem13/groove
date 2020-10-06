class AddFieldToGeneralSetting < ActiveRecord::Migration[5.1]
  def change
  	add_column :general_settings, :cost_calculator_url, :string
  end
end
