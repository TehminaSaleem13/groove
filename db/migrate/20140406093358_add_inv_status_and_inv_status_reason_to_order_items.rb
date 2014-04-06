class AddInvStatusAndInvStatusReasonToOrderItems < ActiveRecord::Migration
  def change
  	add_column :order_items, :inv_status, :string, :default=>'unprocessed'
  	add_column :order_items, :inv_status_reason, :string, :default=>''
  end
end
