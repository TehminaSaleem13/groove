class AddIsIntangibleToProducts < ActiveRecord::Migration[5.1]
  def change
    add_column :products, :is_intangible, :boolean, :default=>false
  end
end
