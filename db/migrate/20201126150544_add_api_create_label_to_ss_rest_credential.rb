class AddApiCreateLabelToSsRestCredential < ActiveRecord::Migration[5.1]
  def change
    add_column :shipstation_rest_credentials, :use_api_create_label, :boolean, default: false
  end
end
