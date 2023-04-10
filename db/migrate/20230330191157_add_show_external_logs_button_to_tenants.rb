class AddShowExternalLogsButtonToTenants < ActiveRecord::Migration[5.1]
    def change
      add_column :tenants, :show_external_logs_button, :boolean, default: false
    end
end
