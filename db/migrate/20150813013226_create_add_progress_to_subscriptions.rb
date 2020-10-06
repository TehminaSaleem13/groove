class CreateAddProgressToSubscriptions < ActiveRecord::Migration[5.1]
  def change
    add_column :subscriptions, :progress, :string, default: "not_started"
  end
end
