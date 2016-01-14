module ProductConcern
  extend ActiveSupport::Concern
  
  included do
    before_filter :groovepacker_authorize!
    before_filter :init_result_obj, only: [:update]
    include ProductsHelper
    include Groovepacker::Orders::ResponseMessage
  end
  
  private
    def update_inventory_info(general_setting)
      return if params[:inventory_warehouses].empty?
      attr_array = get_inv_update_attributes(general_setting)
      
      params[:inventory_warehouses].each_with_index do |inv_wh|
        update_single_warehouse_info(inv_wh, attr_array)
      end
    end

    def update_single_warehouse_info(inv_wh, attr_array)
      product_location = @product.product_inventory_warehousess.find_by_id(inv_wh["info"]["id"])
      attr_array.each do |attr|
        product_location.send("#{attr}=", inv_wh[:info][attr])
      end
      product_location.save
    end

    def get_inv_update_attributes(general_setting)
      attr_array = ['quantity_on_hand', 'location_primary', 'location_secondary', 'location_tertiary']
      if general_setting.low_inventory_alert_email
        attr_array = attr_array + ['product_inv_alert', 'product_inv_alert_level']
      end
      attr_array
    end

    def destroy_object_if_not_defined(objects_array, obj_params, result)
      return result if objects_array.blank?
      
      ids = obj_params.map {|obj| obj["id"]} rescue []
      objects_array.each do |object|
        found_obj = false
        found_obj = true if ids.include?(object.id)
        if found_obj == false && !object.destroy
          result['status'] &= false
        end
      end
      return result
    end

    def update_product_basic_info
      basic_info = params[:basicinfo]
      attrs_to_update.each {|attr| @product[attr] = basic_info[attr] }

      @product.packing_placement = basic_info[:packing_placement] if basic_info[:packing_placement].is_a?(Integer)
      @product.weight = @product.get_product_weight(params[:weight])
      @product.shipping_weight = @product.get_product_weight(params[:shipping_weight])
      @product.weight_format = get_weight_format(basic_info[:weight_format])
      @product.save ? true : false
    end

    def attrs_to_update
      [ "disable_conf_req", "is_kit", "is_skippable", "record_serial", "kit_parsing", "name", "product_type",
        "spl_instructions_4_confirmation", "spl_instructions_4_packer", "store_id", "store_product_id",
        "type_scan_enabled", "click_scan_enabled", "add_to_any_order", "product_receiving_instructions",
        "is_intangible", "pack_time_adj" ]
    end

    def init_result_obj
      @result = { 'status' => true, 'messages' => [] }
    end
end