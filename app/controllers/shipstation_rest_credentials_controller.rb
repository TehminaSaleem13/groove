class ShipstationRestCredentialsController < ApplicationController
  before_action :groovepacker_authorize!

  def fix_import_dates
  	@result = {"status" => true, "messages" => ""}
  	@credential = ShipstationRestCredential.find_by_store_id(params["store_id"])
  	@credential.last_imported_at = 24.hours.ago
  	@credential.quick_import_last_modified = 24.hours.ago
  	if @credential.save
      @result["messages"] = "Successfully Updated"
    else
      @result["messages"] = "Something went wrong"
      @result["status"] = false
    end
  	render json: @result
  end

  def update_product_image
    @result = {"status" => true, "messages" => ""}
    @credential = ShipstationRestCredential.find_by_store_id(params["store_id"])
    @credential.download_ss_image = true
    if @credential.save
      @result["messages"] = "Images will be imported for existing items during the next order import."
    else
      @result["messages"] = "Something went wrong"
      @result["status"] = false
    end
    render json: @result
  end

  def use_chrome_extention
    result = {}
    shipstation_cred = ShipstationRestCredential.find_by_store_id(params["store_id"])
    shipstation_cred.update_attribute(:use_chrome_extention, !shipstation_cred.use_chrome_extention)
    result["use_chrome_extention"] = shipstation_cred.use_chrome_extention  
    render json: result
  end

  def switch_back_button
    result = {}
    shipstation_cred = ShipstationRestCredential.find_by_store_id(params["store_id"])
    shipstation_cred.update_attribute(:switch_back_button, !shipstation_cred.switch_back_button)
    result["switch_back_button"] = shipstation_cred.switch_back_button  
    render json: result
  end


  def use_api_create_label
    result = {}
    shipstation_cred = ShipstationRestCredential.find_by_store_id(params["store_id"])
    shipstation_cred.update_attribute(:use_api_create_label, !shipstation_cred.use_api_create_label)
    result['use_api_create_label'] = shipstation_cred.use_api_create_label
    render json: result
  end

  def auto_click_create_label
    result = {}
    shipstation_cred = ShipstationRestCredential.find_by_store_id(params["store_id"])
    shipstation_cred.update_attribute(:auto_click_create_label, !shipstation_cred.auto_click_create_label)
    result["auto_click_create_label"] = shipstation_cred.auto_click_create_label  
    render json: result
  end

end
