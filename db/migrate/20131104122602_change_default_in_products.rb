class ChangeDefaultInProducts < ActiveRecord::Migration[5.1]
  def up
  	change_column :products, :spl_instructions_4_confirmation, :boolean, {:default=>0}
  	change_column :products, :is_skippable, :boolean, {:default=>0}
  	change_column :products, :status, :string, {:default=>'New'}
  end

  def down
  	change_column :products, :status, :string, {:default=>nil}
  	change_column :products, :is_skippable, :boolean, {:default=>nil}
  	change_column :products, :spl_instructions_4_confirmation, :text, {:default=>nil}
  end
end
