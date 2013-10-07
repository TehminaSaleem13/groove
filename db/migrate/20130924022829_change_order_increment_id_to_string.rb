class ChangeOrderIncrementIdToString < ActiveRecord::Migration
  def up
  	change_column :orders, :increment_id, :string
  end

  def down
  	change_column :orders, :increment_id, :integer
  end
end
