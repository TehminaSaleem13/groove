class AddIsIntangibleToProducts < ActiveRecord::Migration
  def change
    add_column :products, :is_intangible, :boolean, :default=>false
  end
end
