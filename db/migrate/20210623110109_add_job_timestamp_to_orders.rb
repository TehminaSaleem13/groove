class AddJobTimestampToOrders < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :job_timestamp, :string
  end
end
