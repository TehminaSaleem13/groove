class ChangeColumnToGeneralSetting < ActiveRecord::Migration[5.1]
  def up
  	change_column_default :general_settings, :to_import, '2000-01-01 23:59:00'
  end

  def down
  	change_column_default :general_settings, :to_import, '2000-01-01 00:00:00'
  end
end
