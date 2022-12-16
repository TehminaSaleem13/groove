class AddColumnToPrintingSetting < ActiveRecord::Migration[5.1]
  def change
    add_column :printing_settings, :packing_slip_print_size, :string, {:default=> 'Standard 4 x 6'}
  end
end
