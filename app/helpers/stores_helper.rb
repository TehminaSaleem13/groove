module StoresHelper
  def get_default_warehouse_id
    inventory_warehouses = InventoryWarehouse.where(:is_default => 1)
    if !inventory_warehouses.nil?
      inventory_warehouse = inventory_warehouses.first
      default_warehouse_id = inventory_warehouse.id
      default_warehouse_id
    end
  end

  def get_default_warehouse_name
    inventory_warehouses = InventoryWarehouse.where(:is_default => 1)
    if !inventory_warehouses.nil?
      inventory_warehouse = inventory_warehouses.first
      default_warehouse_name = inventory_warehouse.name
      default_warehouse_name
    end
  end

  def init_store_data
    params[:name]=nil if params[:name]=='undefined'
    @store.name = params[:name] || get_default_warehouse_name
    @store.store_type = params[:store_type]
    @store.status = params[:status]
    @store.thank_you_message_to_customer = params[:thank_you_message_to_customer] unless params[:thank_you_message_to_customer] == 'null'
    @store.inventory_warehouse_id = params[:inventory_warehouse_id] || get_default_warehouse_id
    @store.auto_update_products = params[:auto_update_products]
    @store.on_demand_import = params[:on_demand_import]
    @store.update_inv = params[:update_inv]
    @store.save
  end

  def store_duplicate
    @result = {"status"=>true, "messages"=>[]}
    if current_user.can? 'add_edit_stores'
      params['_json'].each do |store|
        if Store.can_create_new?
          @store = Store.find(store["id"])
          @newstore = @store.dup
          index = 0
          @newstore.name = @store.name+"(duplicate"+index.to_s+")"
          @storeslist = Store.where(:name => @newstore.name)
          begin
            index = index + 1
            @newstore.name = @store.name+"(duplicate"+index.to_s+")"
            @storeslist = Store.where(:name => @newstore.name)
          end while (!@storeslist.nil? && @storeslist.length > 0)
          if !@newstore.save(:validate => false) || !@newstore.dupauthentications(@store.id)
            @result['status'] = false
            @result['messages'] = @newstore.errors.full_messages
          end
        else
          @result['status'] = false
          @result['messages'] = "You have reached the maximum limit of number of stores for your subscription."
        end
      end
    else
      @result["status"] = false
      @result["messages"].push("User does not have permissions to duplicate store")
    end
  end

  def store_delete
    @result = {"status"=>false, "messages"=>[]}
    if current_user.can? 'add_edit_stores'
      system_store_id = Store.find_by_store_type('system').id.to_s
      params['_json'].each do |store|
        @store = Store.where(id: store["id"]).first
        unless @store.nil?
          Product.update_all('store_id = '+system_store_id, 'store_id ='+@store.id.to_s)
          Order.update_all('store_id = '+system_store_id, 'store_id ='+@store.id.to_s)
          if @store.store_type == 'CSV'
            csv_mapping = CsvMapping.find_by_store_id(@store.id)
            csv_mapping.destroy unless csv_mapping.nil?
            ftp_credential = FtpCredential.find_by_store_id(@store.id)
            ftp_credential.destroy unless ftp_credential.nil?
          end
          @result['status'] = true if @store.deleteauthentications && @store.destroy
        end
      end
    else
      @result["status"] = false
      @result["messages"].push("User does not have permissions to delete store")
    end
  end

  def show_store
    if !@store.nil? then
      @result['status'] = true
      @result['store'] = @store
      access_restrictions = AccessRestriction.last
      @result['general_settings'] = GeneralSetting.first
      @result['current_tenant'] = Apartment::Tenant.current
      @result['host_url'] = get_host_url
      @result['access_restrictions'] = access_restrictions
      @result['credentials'] = @store.get_store_credentials
      @result['mapping'] = CsvMapping.find_by_store_id(@store.id) if @store.store_type == 'CSV'
    else
      @result['status'] = false
    end
  end

  def get_system_store
    if @store.nil?
      @result['status'] = false
    else
      @result['status'] = true
      @result['store'] = @store
    end
  end

end
