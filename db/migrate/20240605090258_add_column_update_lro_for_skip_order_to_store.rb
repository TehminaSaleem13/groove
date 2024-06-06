class AddColumnUpdateLroForSkipOrderToStore < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :loggly_veeqo_imports, :boolean, default: false
  end
end
