class AddLabelShortcutsToShipstationRestCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :label_shortcuts, :text
  end
end
