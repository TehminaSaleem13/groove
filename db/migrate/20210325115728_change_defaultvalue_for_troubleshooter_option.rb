class ChangeDefaultvalueForTroubleshooterOption < ActiveRecord::Migration[5.1]
  def change 
    change_column_default :stores, :troubleshooter_option, from: false, to: true
  end
end