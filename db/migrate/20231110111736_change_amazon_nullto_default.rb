class ChangeAmazonNulltoDefault < ActiveRecord::Migration[5.1]
  def up
    change_column :amazon_credentials, :merchant_id, :string, default: '', null: true
    change_column :amazon_credentials, :marketplace_id, :string, default: '', null: true
  end

  def down
    change_column :amazon_credentials, :merchant_id, :string, default: nil, null: false
    change_column :amazon_credentials, :marketplace_id, :string, default: nil, null: false
  end
end
