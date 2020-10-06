class AddDisableConfReqToProducts < ActiveRecord::Migration[5.1]
  def change
    add_column :products, :disable_conf_req, :boolean, :default=>0
  end
end
