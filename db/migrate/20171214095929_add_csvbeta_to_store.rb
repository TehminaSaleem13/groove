class AddCsvbetaToStore < ActiveRecord::Migration[5.1]
  def change
  	add_column :stores, :csv_beta, :boolean, :default => false
  end
end
