class ChangeDefaultvalueForCustomerNotes < ActiveRecord::Migration[5.1]
  def change 
    change_column_default :shipstation_rest_credentials, :shall_import_customer_notes, from: false, to: true
    change_column_default :shipstation_rest_credentials, :shall_import_internal_notes, from: false, to: true
  end
end
