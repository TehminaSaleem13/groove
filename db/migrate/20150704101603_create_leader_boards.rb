class CreateLeaderBoards < ActiveRecord::Migration[5.1]
  def change
    create_table :leader_boards do |t|
      t.integer :scan_time
      t.integer :order_id
      t.integer :order_item_count

      t.timestamps
    end
  end
end
