class AddIsVerifySeparatelyToStore < ActiveRecord::Migration[5.1]
  def change
    add_column :stores, :is_verify_separately, :boolean
  end
end
