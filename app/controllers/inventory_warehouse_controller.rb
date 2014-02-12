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
      if inv_wh.save
        result['success_messages'].push('Inventory warehouse created successfully')
      else
        result['status'] &= false
        result['error_messages'].push('There was an error creating inventory warehouse')
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
      inv_wh = InventoryWarehouse.find(params[:id])
      inv_wh.name = params[:name] if !params[:name].nil?
      inv_wh.location = params[:location] if !params[:location].nil?
      inv_wh.save
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
      
    

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def adduser
    result = Hash.new
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
      
    

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

  def removeuser
    result = Hash.new
    result['status'] = true
    result['error_messages'] = []
    result['success_messages'] = []
    result['notice_messages'] = []
      
    

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: result }
    end
  end

end
