class FixColumnName < ActiveRecord::Migration[6.1]
  def change
    rename_column :general_settings, :slidShowTime, :slide_show_time
  end
end
