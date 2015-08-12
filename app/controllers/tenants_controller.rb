  class TenantsController < ApplicationController
    include PaymentsHelper

    def search
      @result = Hash.new
      @result['status'] = true
      if !params[:search].nil? && params[:search] != ''
        helper = Groovepacker::Tenants::Helper.new
        @tenants = helper.do_search(params, false)
        @result['tenants'] = helper.make_tenants_list(@tenants['tenants'])
        @result['tenants_count'] = get_tenants_count
        @result['tenants_count']['search'] = @tenants['count']
      else
        @result['status'] = false
        @result['message'] = 'Improper search string'
      end

      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
      end
    end

    def index
      @result = Hash.new
      @result[:status] = true
      helper = Groovepacker::Tenants::Helper.new
      if !params[:search].nil? && params[:search] != ''
        @tenants = helper.do_search(params, false)
        @result['tenants'] = helper.make_tenants_list(@tenants['tenants'])
        @result['tenants_count'] = get_tenants_count
        @result['tenants_count']['search'] = @tenants['count']
      else
        @tenants = helper.do_gettenants(params)
        @result['tenants'] = helper.make_tenants_list(@tenants)
        @result['tenants_count'] = get_tenants_count()
      end

      respond_to do |format|
        format.json { render json: @result}
      end
    end

    def show
      @result = Hash.new
      @tenant = nil
      if !params[:id].nil?
        @tenant = Tenant.find_by_id(params[:id])
      end
      if !@tenant.nil?
        @tenant.reload
        general_setting = GeneralSetting.all.first
        scan_pack_setting = ScanPackSetting.all.first

        @result['tenant'] = Hash.new
        @result['tenant']['basicinfo'] = @tenant.attributes
        helper = Groovepacker::Tenants::Helper.new
        @result['tenant']['subscription_info'] = helper.get_subscription_data(params[:id])
        @result['tenant']['access_restrictions_info'] = helper.get_shipping_data(params[:id])
      end

      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
      end
    end

    def update_access_restrictions
      @result = Hash.new
      @result['status'] = true
      @result['error_messages'] = []
      @tenant = nil
      tenant = Tenant.find(params[:basicinfo][:id])
      unless tenant.nil?
        helper = Groovepacker::Tenants::Helper.new
        helper.update_restrictions(tenant, params, @result)
      else
        @result['status'] = false
      end
      Apartment::Tenant.switch()

      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
      end
    end

    def delete_tenant_data
      @result = Hash.new
      @result['status'] = true
      @result['error_messages'] = []
      @tenant = nil
      tenant = Tenant.find(params[:id])
      unless tenant.nil?
        helper = Groovepacker::Tenants::Helper.new
        helper.delete_data(tenant, params, @result, current_user)
      else
        @result['status'] = false
      end
      Apartment::Tenant.switch()

      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @result }
      end
    end

    def delete_tenant
      @result = Hash.new
      @result['status'] = true
      @result['error_messages'] = []
      @result['success_messages'] = []
      @tenants = list_selected_tenants
      unless @tenants.nil?
        @tenants.each do|tenant|
          helper = Groovepacker::Tenants::Helper.new
          helper.delete(tenant, @result)
        end
      else
        @result['status'] = false
        @result['error_messages'].push("Selected list is empty")
      end

      respond_to do |format|
          format.html # show.html.erb
          format.json { render json: @result }
      end
    end

    private

    def get_tenants_count
      count = Hash.new
      counts = Tenant.select('count(*) as count')
      all = 0
      counts.each do |single|
        # count[single.status] = single.count
        all += single.count
      end
      count['all'] = all
      count['search'] = 0
      count
    end

    def list_selected_tenants
      tenants_list = params['_json']
      tenants = []
      tenants_list.each do |tenant|
        tenants.push(tenant['name'])
      end
      tenants
    end
  end
