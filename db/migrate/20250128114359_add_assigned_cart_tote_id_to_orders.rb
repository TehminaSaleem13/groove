# frozen_string_literal: true

class AddAssignedCartToteIdToOrders < ActiveRecord::Migration[6.1]
  def change
    add_column :orders, :assigned_cart_tote_id, :string
    add_index :orders, :assigned_cart_tote_id
  end
end