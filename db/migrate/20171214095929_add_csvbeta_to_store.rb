class AddCsvbetaToStore < ActiveRecord::Migration
  def change
  	add_column :stores, :csv_beta, :boolean, :default => false
  end
end
