class AddDefaultTrueToCsvBeta < ActiveRecord::Migration[5.1]
  def up
    change_column :stores, :csv_beta, :boolean, default: true
  end

  def down
    change_column :stores, :csv_beta, :boolean, default: false
  end
end
