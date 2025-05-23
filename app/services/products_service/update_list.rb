# frozen_string_literal: true

module ProductsService
  class UpdateList < ProductsService::Base
    include ProductMethodsHelper

    def initialize(*args)
      @product, @var, @value, @current_user, @permit_same_barcode = args
    end

    def call
      if var_matches_attr_names?
        update_product
      elsif unmatched_var?
        return @product if update_product_for_unmatched_var
      elsif location_params?
        update_product_location
      end
      @product.reload
      @product.update_product_status
    rescue StandardError => e
      puts e.inspect
    end

    def var_matches_attr_names?
      %w[
        name status is_skippable type_scan_enabled
        click_scan_enabled packing_instructions
        custom_product_1 custom_product_2 custom_product_3
      ].include?(@var)
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
      existing_value = @product.send("primary_#{@var}") || 'NONE'
      @permit_same_barcode ? @product.send("primary_#{@var}=", @value, @permit_same_barcode) : @product.send("primary_#{@var}=", @value)
      unless @product.errors.any?
        @product.add_product_activity("The #{@var} of this item was changed from #{existing_value} to #{@value} by #{@current_user}")
      end
      @product.errors.any?
    end

    def unmatched_var?
      @var.in? %w[sku category barcode]
    end

    def location_params?
      %w[
        location_primary location_secondary location_tertiary
        location_name qty_on_hand
      ].include?(@var)
    end

    def location_name(var)
      location_names = {
        "location_primary" => "Primary Location",
        "location_secondary" => "Secondary Location",
        "location_tertiary" => "Tertiary Location"
      }
      location_names[var]
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
      if @var.in? %w[location_primary location_secondary location_tertiary]
        current_location_value = product_location[@var]
        if current_location_value != @value
          product_location[@var] = @value
          @product.add_product_activity(
            "The #{location_name(@var)} was changed from #{current_location_value} to #{@value} — updated", @current_user
          )
        end
      elsif @var == 'location_name'
        product_location.name = @value
      elsif @var == 'qty_on_hand'
        @product.add_product_activity("The QOH of this item was changed from #{product_location.quantity_on_hand} to #{@value} ", @current_user)
        product_location.quantity_on_hand = @value
      end
      product_location.save
    end
  end
end
