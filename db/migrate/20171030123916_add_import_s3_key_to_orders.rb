class AddImportS3KeyToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :import_s3_key, :string
  end
end
