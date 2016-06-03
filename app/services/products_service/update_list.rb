module ProductsService
  class UpdateList < ProductsService::Base
    def initialize(*args)
      @product, @var, @value = args
    end

    def call
      if var_matches_attr_names?
        update_product
      elsif unmatched_var?
        return @product if update_product_for_unmatched_var
      elsif location_params?
        update_product_location
      end
      @product.update_product_status
    rescue => e
      puts e.inspect
    end

    def var_matches_attr_names?
      %w(
        name status is_skippable type_scan_enabled
        click_scan_enabled spl_instructions_4_packer
      ).include?(@var)
    end

    def update_product
      @product[@var] = @value
      @product.save

      return unless @var == 'status'

      if @value == 'inactive'
        @product.update_due_to_inactive_product
      else
        @product.update_product_status
      end
    end

    def update_product_for_unmatched_var
      @product.send("primary_#{@var}=", @value)
      @product.errors.any?
    end

    def unmatched_var?
      @var.in? %w(sku category barcode)
    end

    def location_params?
      %w(
        location_primary location_secondary location_tertiary
        location_name qty_on_hand
      ).include?(@var)
    end

    def find_or_create_product_location
      product_location = @product.primary_warehouse
      unless product_location.present?
        product_location = ProductInventoryWarehouses.new
        product_location.product_id = @product.id
        product_location.inventory_warehouse_id = current_user.inventory_warehouse_id
      end
      product_location
    end

    def update_product_location
      product_location = find_or_create_product_location
      if @var.in? %w(location_primary location_secondary location_tertiary)
        product_location[@var] = @value
      elsif @var == 'location_name'
        product_location.name = @value
      elsif @var == 'qty_on_hand'
        product_location.quantity_on_hand = @value
      end
      product_location.save
    end
  end
end
