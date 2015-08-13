class CreateAddProgressToSubscriptions < ActiveRecord::Migration
  def change
    add_column :subscriptions, :progress, :string, default: "not_started"
  end
end
