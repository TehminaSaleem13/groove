class ChangeDefaultStatusInProducts < ActiveRecord::Migration
  def up
    change_column :products, :status, :string, {:default=>'new'}
  end

  def down
    change_column :products, :status, :string, {:default=>'New'}
  end
end
