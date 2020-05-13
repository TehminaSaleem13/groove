class ChangeProductFields < ActiveRecord::Migration
  def up
    rename_column :products, :spl_instructions_4_packer, :packing_instructions if column_exists? :products, :spl_instructions_4_packer
    rename_column :products, :spl_instructions_4_confirmation, :packing_instructions_conf if column_exists? :products, :spl_instructions_4_confirmation
  end

  def down
    rename_column :products, :packing_instructions, :spl_instructions_4_packer if column_exists? :products, :packing_instructions
    rename_column :products, :packing_instructions_conf, :spl_instructions_4_confirmation if column_exists? :products, :packing_instructions_conf
  end
end
