class AddImportS3KeyToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :import_s3_key, :string
  end
end
