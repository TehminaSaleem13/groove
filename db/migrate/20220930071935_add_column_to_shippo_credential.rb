class AddColumnToShippoCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shippo_credentials, :last_imported_at, :datetime
    add_column :shippo_credentials, :generate_barcode_option, :string, default: "do_not_generate" 
  end
end
