# frozen_string_literal: true

class InventoryWarehouseController < ApplicationController
  before_action :groovepacker_authorize!
  # this action creates a warehouse with a name
  include InventoryWarehouseHelper

  def create
    result = {}
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []

    if !params[:inv_info][:name].nil?
      inv_wh = InventoryWarehouse.new
      inv_wh.name = params[:inv_info][:name]
      inv_wh.location = params[:inv_info][:location] unless params[:inv_info][:location].nil?
      inv_wh.status = params[:inv_info][:status]

      if inv_wh.save
        result['success_messages'].push('Inventory warehouse created successfully')
        unless params[:inv_wh_users].nil?
          params[:inv_users].each do |inv_user_id|
            inv_wh.users << User.find(inv_user_id)
          end
        end
        inv_wh.save
        result['inv_wh_info'] = inv_wh
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
    result = {}
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []

    if !params[:id].nil?
      begin
        inv_wh = InventoryWarehouse.find(params[:id])
        if !inv_wh.nil?
          inv_wh.name = params[:name] unless params[:name].nil?
          inv_wh.location = params[:location] unless params[:location].nil?
          inv_wh.status = params[:status] unless params[:status].nil?
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
          result['error_messages'].push('No warehouse found with id:' + params[:id])
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
    result = {}
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    result['data'] = {}

    if !params[:id].nil?
      inv_wh = InventoryWarehouse.find(params[:id])
      if !inv_wh.nil?
        result['data']['inv_wh_info'] = inv_wh
        result['data']['inv_wh_users'] = inv_wh.users
      else
        result['error_messages'].push('Could not find inventory warehouse with id:' + params[:id])
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
    result = {}
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    result['data'] = {}

    inv_whs = InventoryWarehouse.all
    result['data']['inv_whs'] = []

    inv_whs.each do |inv_wh|
      next unless current_user.can?('make_super_admin') || !UserInventoryPermission.where(
        user_id: current_user.id,
        inventory_warehouse_id: inv_wh.id,
        see: true
      ).empty?

      warehouse_info = {}
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
    result = {}
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []

    if !params[:inv_wh_ids].nil?
      params[:inv_wh_ids].each do |inv_wh_id|
        inv_wh = InventoryWarehouse.find(inv_wh_id)
        if !inv_wh.nil?
          unless inv_wh.destroy
            result['status'] &= false
            result['error_messages'].push('There was an error deleting the warehouse with id: ' + inv_wh_id)
          end
        else
          result['status'] &= false
          result['error_messages'].push('There is no inventory warehouse with id: ' + inv_wh_id)
        end
      rescue Exception => e
        result['status'] &= false
        result['error_messages'].push(e.message)
      end
    else
      result['status'] &= false
      result['error_messages'].push('Cannot delete inventory without id: ' + params[:id])
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  # get list of available users
  def available_users
    result = {}
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
    result['data'] = {}
    result['data']['available_users'] = []

    User.all.each do |user|
      available_user = {}
      available_user['user_info'] = user
      available_user['user_info']['role'] = user.role
      available_user['checked'] = false
      available_user['user_perms'] = {}
      unless params[:inv_wh_id].nil?
        available_user['user_perms'] = fix_user_inventory_permissions(user, InventoryWarehouse.find(params[:inv_wh_id]))
        available_user['checked'] = true if params[:inv_wh_id].to_i == user.inventory_warehouse_id
      end
      result['data']['available_users'] << available_user
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def edit_user_perms
    result = {}
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []

    if params[:id].nil? || params[:user].nil? || params[:user]['user_info']['id'].nil?
      result['status'] &= false
      result['error_messages'].push('Cannot add user to the inventory warehouse without a warehouse id and user.')
    else
      inv_wh = InventoryWarehouse.find(params[:id])
      user = User.find(params[:user]['user_info']['id'])
      if inv_wh.nil?
        result['status'] &= false
        result['error_messages'].push('There is no inventory warehouse with id: ' + params[:id])
      elsif user.nil?
        result['status'] &= false
        result['error_messages'].push('There is no user with id:' + params[:user]['user_info']['id'])
      else
        if params[:user]['checked']
          user.inventory_warehouse_id = inv_wh.id
          if user.save
            result['success_messages'].push('User is successfully added to the warehouse')
          else
            result['status'] &= false
            user.errors.full_messages.each do |message|
              result['error_messages'].push(message)
            end
            result['error_messages'].push('There was an error adding user to inventory warehouse')
          end
        end
        unless params[:user]['user_perms'].nil?
          inventory_perms = UserInventoryPermission.find(params[:user]['user_perms']['id'])
          inventory_perms['edit'] = params[:user]['user_perms']['edit']
          inventory_perms['edit'] = false unless user.can?('add_edit_products')
          inventory_perms['see'] = params[:user]['user_perms']['see']
          if inventory_perms.save
            result['success_messages'].push('User permissions successfully saved to the warehouse')
          else
            result['status'] &= false
            inventory_perms.errors.full_messages.each do |message|
              result['error_messages'].push(message)
            end
            result['error_messages'].push('There was an error editing user permissions with the inventory warehouse')
          end
        end

      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  # change status to params[:status] for all inv_whs in the inv_wh_ids list
  def changestatus
    result = {}
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []

    params[:inv_wh_ids].each do |inv_wh_id|
      inv_wh = InventoryWarehouse.find(inv_wh_id)
      unless inv_wh.nil?
        inv_wh.status = params[:status]
        unless inv_wh.save
          result['status'] &= false
          result['error_messages'].push('There was an error changing status for inventory warehouse id: ' +
                                          inv_wh_id)
        end
      end
    rescue Exception => e
      result['status'] &= false
      result['error_messages'].push(e.message)
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end
end
