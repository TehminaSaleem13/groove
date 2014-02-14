class InventoryWarehouseController < ApplicationController
  #add before filter here
  # this action creates a warehouse with a name
  def create
    result = Hash.new
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    
    if !params[:name].nil?
      inv_wh = InventoryWarehouse.new
      inv_wh.name = params[:name]
      inv_wh.location = params[:location] if !params[:location].nil?
      inv_wh.status = 'new'
      if inv_wh.save
        result['success_messages'].push('Inventory warehouse created successfully')
      else
        result['status'] &= false
        inv_wh.errors.full_messages.each do |message|
          result['error_messages'].push(message)
        end
      end
    else
      result['status'] &= false
      result['error_messages'].push('Cannot create warehouse without a name')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def update
    result = Hash.new
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    
    if !params[:id].nil?
      begin
        inv_wh = InventoryWarehouse.find(params[:id])
        if !inv_wh.nil?
          inv_wh.name = params[:name] if !params[:name].nil?
          inv_wh.location = params[:location] if !params[:location].nil?
          inv_wh.status = params[:status] if !params[:status].nil?
          if inv_wh.save
            result['success_messages'].push('Inventory warehouse updated successfully')
          else
            result['status'] &= false
            inv_wh.errors.full_messages.each do |message|
              result['error_messages'].push(message)
            end
          end
        else
          result['status'] &= false
          result['error_messages'].push('No warehouse found with id:'+params[:id])
        end
      rescue Exception => e
          result['status'] &= false
          result['error_messages'].push(e.message)
      end
    else
      result['status'] &= false
      result['error_messages'].push('Cannot update warehouse without a id')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def show
    result = Hash.new
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    result['data'] = Hash.new

    if !params[:id].nil?
      inv_wh = InventoryWarehouse.find(params[:id])
      if !inv_wh.nil?
        result['data']['inv_wh_info'] = inv_wh
        result['data']['inv_wh_users'] = inv_wh.users
      else
        result['error_messages'].push('Could not find inventory warehouse with id:'+params[:id])
      end
    else
      result['status'] &= false
      result['error_messages'].push('Cannot find warehouse without a id')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def index
    result = Hash.new
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    result['data'] = Hash.new

    inv_whs = InventoryWarehouse.all
    result['data']['inv_whs'] = []

    inv_whs.each do |inv_wh|
      warehouse_info = Hash.new
      warehouse_info['info'] = inv_wh
      warehouse_info['users'] = inv_wh.users
      result['data']['inv_whs'].push(warehouse_info)
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def destroy
    result = Hash.new
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
      
    if !params[:id].nil?
      inv_wh = InventoryWarehouse.find(params[:id])
      if !inv_wh.nil?
        if inv_wh.destroy
          result['success_messages'].push('Inventory warehouse deleted successfully')
        else
          result['status'] &= false
          result['error_messages'].push('There was an error deleting the warehouse')
        end
      else
        result['status'] &= false
        result['error_messages'].push('There is no inventory warehouse with id: '+ params[:id])
      end
    else
      result['status'] &= false
      result['error_messages'].push('Cannot delete inventory without id: '+ params[:id])
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  #add user to inventory warehouse where id is inventory warehouse and user_id is id of the user to 
  #be added
  def adduser
    result = Hash.new
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    
    if !params[:id].nil?
      inv_wh = InventoryWarehouse.find(params[:id])
      if !inv_wh.nil?
        if !params[:user_id].nil?
          #if a user is already associated with an inven
          user = User.find(params[:user_id])
          if !user.nil?
            if user.inventory_warehouse.nil?
              user.inventory_warehouse  = inv_wh
              if user.save
                result['success_messages'].push('User is successfully added to the warehouse')
              else
                result['status'] &= false
                result['error_messages'].push('There was an error adding user to inventory warehouse')
              end
            else
              result['status'] &= false
              result['error_messages'].push('User is already associated with a warehouse')
            end
          else
            result['status'] &= false
            result['error_messages'].push('There is no user with id:'+params[:user_id])
          end
        else
          result['status'] &= false
          result['error_messages'].push('Cannot add user without a user id.')
        end
      else
        result['status'] &= false
        result['error_messages'].push('There is no inventory warehouse with id: '+ params[:id])
      end
    else
      result['status'] &= false
      result['error_messages'].push('Cannot add user to the inventory warehouse without a warehouse id.')
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  #remove user from inventory warehouse where id is inventory warehouse id and user_id is id of the user to 
  #be removed
  def removeuser
    result = Hash.new
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []

    if !params[:id].nil?
      inv_wh = InventoryWarehouse.find(params[:id])
      if !inv_wh.nil?
        if !params[:user_id].nil?
          #if a user is already associated with an inven
          user = User.find(params[:user_id])
          if !user.nil?
            if !user.inventory_warehouse.nil?
              user.inventory_warehouse  = nil
              if user.save
                result['success_messages'].push('User is successfully removed from the warehouse')
              else
                result['status'] &= false
                result['error_messages'].push('There was an error removing user from inventory warehouse')
              end
            else
              result['status'] &= false
              result['error_messages'].push('User is not associated with any warehouse')
            end
          else
            result['status'] &= false
            result['error_messages'].push('There is no user with id:'+params[:user_id])
          end
        else
          result['status'] &= false
          result['error_messages'].push('Cannot remove user without a user id.')
        end
      else
        result['status'] &= false
        result['error_messages'].push('There is no inventory warehouse with id: '+ params[:id])
      end
    else
      result['status'] &= false
      result['error_messages'].push('Cannot remove user from the inventory warehouse without a warehouse id.')
    end      
    

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

end
