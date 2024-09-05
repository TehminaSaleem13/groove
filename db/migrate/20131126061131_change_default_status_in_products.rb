class ChangeDefaultStatusInProducts < ActiveRecord::Migration[5.1]
  def up
    change_column :products, :status, :string, :default=>'new'
  end

  def down
    change_column :products, :status, :string, {:default=>'New'}
  end
end
