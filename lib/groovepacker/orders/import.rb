module Groovepacker
  module Orders
    class Import < Groovepacker::Orders::Base

      def execute_import
        store = Store.find(@params[:id])
        @result = @result.merge(import_status_hash)
        @result['activestoreindex'] = @params[:activestoreindex] unless @params[:activestoreindex].blank?

        begin
          #import if magento products
          import_result = get_context(store).import_orders
        rescue Exception => e
          set_status_and_message(false, e.message, ['push'])
        end
        return @result, import_result
      end

      def start_import_for_all
        order_summary = OrderImportSummary.where(status: 'in_progress')
        unless order_summary.empty?
          set_status_and_message(false, 'Import is in progress', ['push', 'error_messages'])
          return @result
        end
        if Store.where("status = '1' AND store_type != 'system'").length > 0
          add_import_to_delayed_job(order_summary)
          @result['success_messages'].push('Scouring the interwebs for new orders...')
        else
          set_status_and_message(false, 'You currently have no Active Stores in your Store List', ['push', 'error_messages'])
        end
        return @result
      end

      def import_ftp_order(tenant)
        Apartment::Tenant.switch(tenant)
        user = User.where(username: "gpadmin").first
        if OrderImportSummary.where(status: 'in_progress').blank?
          stores = Store.includes(:ftp_credential).where('store_type = ? && ftp_credentials.use_ftp_import = ?', 'CSV', true)
          result = Hash[:status => true]
          (stores || []).each do |store|
            while result[:status] == true do
              groove_ftp = FTP::FtpConnectionManager.get_instance(store)
              result = groove_ftp.retrieve()
              if result[:status] == true
                create_order_import_summary(store, user, tenant)
                begin
                  ImportOrders.new.initiate_csv_import(tenant, store.store_type, store, @import_item)
                  @order_summary.update_attribute(:status, 'completed') if @order_summary.status != 'cancelled'
                rescue Exception => e
                  result[:status] &= false
                  @import_item.update_attribute(:message, e.message)
                  ImportMailer.failed({ tenant: tenant, import_item: @import_item, exception: e }).deliver
                end
              end
            end             
          end
        end 
      end

      def create_order_import_summary(store, user, tenant)
        Apartment::Tenant.switch(tenant)
        @order_summary = OrderImportSummary.last
        @order_summary = OrderImportSummary.create(user_id: user.id, import_summary_type: "import_orders", status: 'not_started') if @order_summary.blank?
        ImportItem.where("store_id=? and status!='in_progress'", store.id).destroy_all
        @order_summary.reload
        @import_item = @order_summary.import_items.build(store_id: store.id)
        @import_item.status = 'not_started'
        @import_item.save
        @import_item.reload
      end

      def import_shipworks(auth_token, request, status = 200)
        return status if @params[:auth_token].nil? || request.headers["HTTP_USER_AGENT"] != 'shipworks'

        begin
          #find store/credential by using the auth_token
          credential = ShipworksCredential.find_by_auth_token(auth_token)
          status = create_or_update_item(credential, status)
        rescue Exception => e
          tenant = Apartment::Tenant.current
          ImportMailer.failed({ tenant: tenant, import_item: @import_item, exception: e }).deliver rescue nil
          @import_item.status = 'failed'
          @import_item.message = e.message
          @import_item.save
          status = 401
        end
        return status
      end

      private
        def add_import_to_delayed_job(order_summary)
          order_summary_info = OrderImportSummary.create(user_id: @current_user.id, status: 'not_started', display_summary: true)
          # call delayed job
          tenant = Apartment::Tenant.current
          import_orders_obj = ImportOrders.new
          Delayed::Job.where(queue: "importing_orders_#{tenant}").destroy_all
          import_orders_obj.delay(:run_at => 1.seconds.from_now, :queue => "importing_orders_#{tenant}").import_orders tenant
          #import_orders_obj.import_orders tenant
        end

        def create_or_update_item(credential, status)
          return 401 unless !(credential.nil? || !credential.store.status)
          @import_item = ImportItem.find_by_store_id(credential.store.id)
          @import_item = ImportItem.create_or_update(@import_item, credential)
          shipwork_handler = Groovepacker::Stores::Handlers::ShipworksHandler.new(credential.store, @import_item)
          Groovepacker::Stores::Context.new(shipwork_handler).import_order(@params["ShipWorks"]["Customer"]["Order"])
          change_status_if_not_failed
          return status
        end
        
        def change_status_if_not_failed
          return unless @import_item.status != 'failed'
          @import_item.update_attributes(:status => 'completed')
        end

        def import_status_hash
          return {  'total_imported' => 0,
                    'success_imported' => 0,
                    'previous_imported' => 0,
                    'activestoreindex' => 0
                  }
        end
    end
  end
end