class StartingValueChangeColumnType < ActiveRecord::Migration[5.1]
  def change
    change_column(:general_settings, :starting_value, :string)
  end
end
