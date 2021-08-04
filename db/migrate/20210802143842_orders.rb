class Orders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :tags, :string
  end
end
