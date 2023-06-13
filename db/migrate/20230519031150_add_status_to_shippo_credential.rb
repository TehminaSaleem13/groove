class AddStatusToShippoCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shippo_credentials, :import_paid, :boolean, default:false
    add_column :shippo_credentials, :import_awaitpay, :boolean, default:false
    add_column :shippo_credentials, :import_partially_fulfilled, :boolean, default:false
    add_column :shippo_credentials, :import_shipped, :boolean, default:false
    add_column :shippo_credentials, :import_any, :boolean, default:false
  end
end
