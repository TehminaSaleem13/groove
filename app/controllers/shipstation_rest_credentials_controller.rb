# frozen_string_literal: true

class ShipstationRestCredentialsController < ApplicationController
  before_action :groovepacker_authorize!

  def fix_import_dates
    @result = { 'status' => true, 'messages' => '' }
    @credential = ShipstationRestCredential.find_by_store_id(params['store_id'])
    @credential.last_imported_at = 24.hours.ago
    @credential.quick_import_last_modified = 24.hours.ago
    if @credential.save
      @result['messages'] = 'Successfully Updated'
    else
      @result['messages'] = 'Something went wrong'
      @result['status'] = false
    end
    render json: @result
  end

  def update_product_image
    @result = { 'status' => true, 'messages' => '' }
    @credential = ShipstationRestCredential.find_by_store_id(params['store_id'])
    @credential.download_ss_image = true
    if @credential.save
      @result['messages'] = 'Images will be imported for existing items during the next order import.'
    else
      @result['messages'] = 'Something went wrong'
      @result['status'] = false
    end
    render json: @result
  end

  def use_chrome_extention
    result = {}
    shipstation_cred = ShipstationRestCredential.find_by_store_id(params['store_id'])
    shipstation_cred.update_attribute(:use_chrome_extention, !shipstation_cred.use_chrome_extention)
    result['use_chrome_extention'] = shipstation_cred.use_chrome_extention
    render json: result
  end

  def switch_back_button
    result = {}
    shipstation_cred = ShipstationRestCredential.find_by_store_id(params['store_id'])
    shipstation_cred.update_attribute(:switch_back_button, !shipstation_cred.switch_back_button)
    result['switch_back_button'] = shipstation_cred.switch_back_button
    render json: result
  end

  def use_api_create_label
    result = {}
    shipstation_cred = ShipstationRestCredential.find_by_store_id(params['store_id'])
    shipstation_cred.update_attribute(:use_api_create_label, !shipstation_cred.use_api_create_label)
    result['use_api_create_label'] = shipstation_cred.use_api_create_label
    render json: result
  end

  def auto_click_create_label
    result = {}
    shipstation_cred = ShipstationRestCredential.find_by_store_id(params['store_id'])
    shipstation_cred.update_attribute(:auto_click_create_label, !shipstation_cred.auto_click_create_label)
    result['auto_click_create_label'] = shipstation_cred.auto_click_create_label
    render json: result
  end

  def set_label_shortcut
    result = { status: true }
    shipstation_cred = ShipstationRestCredential.find_by_id(params['credential_id'])
    shortcuts = shipstation_cred.label_shortcuts || {}
    new_shortcut = params[:shortcut].permit!.to_h
    shortcuts.delete(shortcuts.key(new_shortcut.values.first)) if shortcuts.key(new_shortcut.values.first)
    shortcuts[new_shortcut.keys.first] = new_shortcut.values.first
    shipstation_cred.label_shortcuts = shortcuts
    shipstation_cred.save
    result[:label_shortcuts] = shipstation_cred.label_shortcuts
    render json: result
  end

  def set_ss_label_advanced
    result = { status: true }
    shipstation_cred = ShipstationRestCredential.find_by_id(params['credential_id'])
    shipstation_cred.skip_ss_label_confirmation = params[:skip_ss_label_confirmation]
    shipstation_cred.save
    render json: result
  end

  def set_carrier_visibility
    result = { status: true }
    shipstation_cred = ShipstationRestCredential.find_by_id(params['credential_id'])
    shipstation_cred.disabled_carriers = if shipstation_cred.disabled_carriers.include? params[:carrier_code]
                                           shipstation_cred.disabled_carriers.reject! { |c| c == params[:carrier_code] }
                                         else
                                           shipstation_cred.disabled_carriers.push(params[:carrier_code]).uniq
                                         end
    shipstation_cred.save
    render json: result
  end

  def set_rate_visibility
    result = { status: true }
    shipstation_cred = ShipstationRestCredential.find_by_id(params['credential_id'])
    shipstation_cred.disabled_rates[params[:disable_rates].keys.first] = params[:disable_rates].values.first if params[:disable_rates]
    shipstation_cred.save
    render json: result
  end

  def set_contracted_carriers
    shipstation_cred = ShipstationRestCredential.find_by_id(params[:credential_id])
    if shipstation_cred.contracted_carriers.include? params[:carrier_code]
      shipstation_cred.contracted_carriers = shipstation_cred.contracted_carriers.reject! { |c| c == params[:carrier_code] }
    else
      shipstation_cred.contracted_carriers = shipstation_cred.contracted_carriers.push(params[:carrier_code]).uniq if params[:carrier_code]
    end
    shipstation_cred.save
    render json: { status: true }
  end

  def set_presets
    result = { status: true }
    shipstation_cred = ShipstationRestCredential.find_by_id(params['credential_id'])
    shipstation_cred.presets = params['presets'].permit!.to_h if shipstation_cred.present?
    shipstation_cred.save
    render json: result
  end
end
