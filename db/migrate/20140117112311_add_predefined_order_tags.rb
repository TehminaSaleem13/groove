class AddPredefinedOrderTags < ActiveRecord::Migration
  def up
  	add_column :order_tags, :predefined, :boolean, :default => 0
  	contains_new_tag = OrderTag.create(:name=>'Contains New', :color=>'#FF0000', :predefined => true)
  	contains_inactive_tag = OrderTag.create(:name=>'Contains Inactive', :color=>'#00FF00', :predefined => true)
  	manual_hold_tag = OrderTag.create(:name=>'Manual Hold', :color=>'#0000FF', :predefined => true)
  end

  def down
  	OrderTag.destroy_all
  	remove_column :order_tags, :predefined
  end
end
