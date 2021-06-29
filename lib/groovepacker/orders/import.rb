module Groovepacker
  module Orders
    class Import < Groovepacker::Orders::Base
      require 'import_orders'

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
        tenant = Apartment::Tenant.current
        tenant = Tenant.where(name: "#{tenant}").first
        if tenant.uniq_shopify_import
          if Store.where("status = '1' AND store_type != 'system'").where(store_type: "Shopify").length > 0
            unless uniq_job_detail == nil
              if ((@job_timestamp.to_time.to_f - Time.now.strftime("%Y-%m-%d %H:%M:%S.%L").to_time.to_f).abs < 3)
                set_status_and_message(false, 'Import is already in progress', ['push', 'error_messages'])
                
                on_demand_logger = Logger.new("#{Rails.root}/log/shopify_import#{Apartment::Tenant.current}.log")
                log = { message: 'Terminate import because of two worker working on same job' }
                on_demand_logger.info(log)
                return @result
              end
            end
                    
            update_uniq_job_table
            sleep 1
            if @job_id.present?
              if UniqJobTable.where(job_id: "#{@job_id}").group_by(&:created_at).count >= 2
                set_status_and_message(false, 'Import is already in progress', ['push', 'error_messages'])
              
                on_demand_logger = Logger.new("#{Rails.root}/log/shopify_import#{Apartment::Tenant.current}.log")
                log = { message: 'Terminate import because of two worker working on same job' }
                on_demand_logger.info(log)
                return @result 
              end
            end
          end
        end

        if $redis.get("importing_orders_#{Apartment::Tenant.current}")
          set_status_and_message(false, 'Import is in progress', ['push', 'error_messages'])
          return @result
        else
          $redis.set("importing_orders_#{Apartment::Tenant.current}", true)
          $redis.expire("importing_orders_#{Apartment::Tenant.current}", 8)
        end

        order_summary = OrderImportSummary.where(status: 'in_progress')

        if order_summary.present?
          set_status_and_message(false, 'Import is in progress', ['push', 'error_messages'])
          return @result
        end

        Groovepacker::Products::Products.new.ftp_product_import(Apartment::Tenant.current) if Tenant.where(name: Apartment::Tenant.current).first.product_ftp_import rescue nil

        if Store.where("status = '1' AND store_type != 'system'").length > 0
          add_import_to_delayed_job(order_summary)
          st = Store.where(store_type: "Shipstation API 2",status: true)
          data = []
          st.each do |s|
            if s.shipstation_rest_credential.api_key.nil? || s.shipstation_rest_credential.api_secret.nil?
              set_status_and_message(false, 'Please click here to open your ShipStation connection settings and add your API details.', ['push', 'error_messages'])
            end
          end
          @result['success_messages'].push('Scouring the interwebs for new orders...')
        else
          set_status_and_message(false, 'You currently have no Active Stores in your Store List', ['push', 'error_messages'])
        end
        return @result
      end

      # def import_ftp_order(tenant)
      #   Apartment::Tenant.switch!(tenant)
      #   user = User.where(username: "gpadmin").first
      #   if OrderImportSummary.where(status: 'in_progress').blank?
      #     stores = Store.includes(:ftp_credential).where('host IS NOT NULL and username IS NOT NULL and password IS NOT NULL and status=true and store_type = ? && ftp_credentials.use_ftp_import = ?', 'CSV', true)
      #     result = Hash[:status => true]
      #     (stores || []).each do |store|
      #       #while result[:status] == true do
      #         groove_ftp = FTP::FtpConnectionManager.get_instance(store)
      #         result = groove_ftp.retrieve()
      #         if result[:status] == true
      #           begin
      #             create_order_import_summary(store, user, tenant)
      #             ImportOrders.new.initiate_csv_import(tenant, store.store_type, store, @import_item)
      #             @order_summary.update_attribute(:status, 'completed') if @order_summary.status != 'cancelled'
      #           rescue Exception => e
      #             result[:status] &= false
      #             @import_item.update_attribute(:message, e.message)
      #             Rollbar.error(e, e.message, Apartment::Tenant.current)
      #             ImportMailer.failed({ tenant: tenant, import_item: @import_item, exception: e }).deliver
      #           end
      #         end
      #       #end
      #     end
      #   end
      # end

      def ftp_order_import(tenant)
        stores = Store.joins(:ftp_credential).where('host IS NOT NULL and username IS NOT NULL and password IS NOT NULL and status=true and store_type = ? && ftp_credentials.use_ftp_import = ?', 'CSV', true)
        stores.each do |store|
          params = {}
          ftp_csv_import = ImportOrders.new
          params[:tenant] = tenant
          params[:user] = User.find_by_name('gpadmin')
          params[:store] = store
          params[:import_type] = 'regular'
          params[:days] = nil
          ftp_csv_import.run_import_for_single_store(params)
        end
      end

      def create_order_import_summary(store, user, tenant)
        Apartment::Tenant.switch!(tenant)
        @order_summary = OrderImportSummary.last
        @order_summary.update_attribute(:status, "not_started") if @order_summary.present?
        @order_summary = OrderImportSummary.create(user_id: user.id, import_summary_type: "import_orders", status: 'not_started') if @order_summary.blank?
        ImportItem.where("store_id=? and status!='in_progress'", store.id).destroy_all
        @order_summary.reload
        @import_item = @order_summary.import_items.build(store_id: store.id)
        @import_item.status = 'not_started'
        @import_item.save
        new_import_item = @import_item
        @import_item = ImportItem.find(@import_item.id) rescue new_import_item
      end

      def import_shipworks(auth_token, request, status = 200)
        return status if @params[:auth_token].nil? || request.headers["HTTP_USER_AGENT"] != 'shipworks'

        begin
          #find store/credential by using the auth_token
          credential = ShipworksCredential.find_by_auth_token(auth_token)
          tenant = Apartment::Tenant.current
          value = Hash.from_xml(request.body.read)
          if Tenant.where(name: tenant).last.is_delay == false
            status = create_or_update_item(credential, status, value)
          else
            return 401 unless !(credential.nil? || !credential.store.status)
            cred = {}
            cred[:id] = credential.id
            import_item = ImportItem.find_by_store_id(credential.store.id)
            import_item = ImportItem.create_or_update(import_item, credential)
            import_orders_obj = ImportOrders.new(@params)
            import_orders_obj.delay(:run_at => 1.seconds.from_now, :queue => "shipworks_importing_orders_#{tenant}", priority: 95).start_shipwork_import(cred, status, value, tenant)
          end
        rescue Exception => e
          tenant = Apartment::Tenant.current
          ImportMailer.failed({ tenant: tenant, import_item: @import_item, exception: e }).deliver rescue nil
          @import_item.status = 'failed'
          @import_item.message = e.message
          @import_item.save
          Rollbar.error(e, e.message, Apartment::Tenant.current)
          status = 401
        end
        return status
      end

      private

        def update_uniq_job_table
          tenant = Apartment::Tenant.current
          Apartment::Tenant.switch!("#{tenant}")
          # @tenant = Tenant.where(name: "#{tenant}").first
          if UniqJobTable.last.blank?
            UniqJobTable.create(worker_id: 'worker_' + SecureRandom.hex, job_timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S.%L"), job_id: "#{tenant}_shopify_import-#{UniqJobTable.new.job_count + 1}", job_count: UniqJobTable.new.job_count + 1)
          else
            UniqJobTable.create(worker_id: 'worker_' + SecureRandom.hex, job_timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S.%L"), job_id: "#{tenant}_shopify_import-#{UniqJobTable.last.job_count + 1}", job_count: UniqJobTable.last.job_count + 1)
          end
          # uniq_job_table.update_attributes(job_timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S.%L", worker_id: @worker_id, job_id: "#{tenant}_se_#{job_count}")        
        end
      
        def uniq_job_detail
          tenant = Apartment::Tenant.current
          Apartment::Tenant.switch!("#{tenant}")
          @job_id = UniqJobTable.last.job_id unless UniqJobTable.last.blank?
          @job_timestamp = UniqJobTable.last.job_timestamp unless UniqJobTable.last.blank?
        end
 
        def add_import_to_delayed_job(order_summary)
          order_summary_info = OrderImportSummary.create(user_id: @current_user.id, status: 'not_started', display_summary: true)
          # call delayed job
          tenant = Apartment::Tenant.current
          @params[:user_id] = @current_user.id
          import_orders_obj = ImportOrders.new(@params)
          Delayed::Job.where(queue: "importing_orders_#{tenant}").destroy_all
          import_orders_obj.delay(:run_at => 1.seconds.from_now, :queue => "importing_orders_#{tenant}", priority: 95).import_orders tenant
          # import_orders_obj.import_orders tenant
        end

        def create_or_update_item(credential, status, value)
          return 401 unless !(credential.nil? || !credential.store.status)
          @import_item = ImportItem.find_by_store_id(credential.store.id)
          @import_item = ImportItem.create_or_update(@import_item, credential)
          shipwork_handler = Groovepacker::Stores::Handlers::ShipworksHandler.new(credential.store, @import_item)
          Groovepacker::Stores::Context.new(shipwork_handler).import_order(value["ShipWorks"]["Customer"]["Order"]) if value["ShipWorks"]["Customer"].present?
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
