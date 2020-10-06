class AddNonHyphenIncrementIdToOrders < ActiveRecord::Migration[5.1]
  include ApplicationHelper
  def change
    add_column :orders, :non_hyphen_increment_id, :string
    Order.all.each do |order|
      order.non_hyphen_increment_id = non_hyphenated_string(order.increment_id) unless order.increment_id.nil?
      order.save
    end
  end
end
