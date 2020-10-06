class ChangeDefaultForConfirmationCode < ActiveRecord::Migration[5.1]
  def up
  	change_column :users, :confirmation_code, :string, :null=> false
  end

  def down
  	change_column :users, :confirmation_code, :string, :null=>true
  end
end
