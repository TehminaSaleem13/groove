class SetDefaultTrueLabelToTenant < ActiveRecord::Migration[6.1]
    def change
      change_column :tenants, :ss_api_create_label, :boolean, default: true
      change_column :tenants, :direct_printing_options, :boolean, default: true
      change_column :tenants, :product_activity_switch, :boolean, default: true
      change_column :tenants, :custom_product_fields, :boolean, default: true
    end
end
