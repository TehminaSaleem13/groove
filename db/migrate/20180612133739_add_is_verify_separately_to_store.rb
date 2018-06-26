class AddIsVerifySeparatelyToStore < ActiveRecord::Migration
  def change
    add_column :stores, :is_verify_separately, :boolean
  end
end
