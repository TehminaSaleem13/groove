class ChangeDefaultOnProductKitParsing < ActiveRecord::Migration[5.1]
  def up
    change_column :products, :kit_parsing, :string,:default => 'individual'
  end

  def down
		change_column :products, :kit_parsing, :string,:default => 'depends'
  end
end
