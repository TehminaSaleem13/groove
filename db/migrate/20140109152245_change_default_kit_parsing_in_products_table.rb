class ChangeDefaultKitParsingInProductsTable < ActiveRecord::Migration
  def up
    change_column :products, :kit_parsing, :string, {:default=>'depends'}
  end

  def down
    change_column :products, :kit_parsing, :string, {:default=>nil}
  end
end
