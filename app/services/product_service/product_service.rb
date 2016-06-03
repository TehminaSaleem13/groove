module ProductService
  class ProductService
    include ProductsHelper

    def initialize(attrs={})
      @result = attrs[:result]
      @params = attrs[:params]
      @current_user = attrs[:current_user]
    end

    def import_images(store)
      @store = store
      unless @current_user.can?('import_products')
        @result['status'] = false
        @result['messages'].push('You can not import images')
        return @result
      end
      import_result = import_images_for_single_store

      unless import_result.nil?
        import_result[:messages].each {|msg| @result['messages'].push(msg)}
        @result['total_imported'] = import_result[:total_imported]
        @result['success_imported'] = import_result[:success_imported]
        @result['previous_imported'] = import_result[:previous_imported]
      end

      return @result
    end

    private
      def import_images_for_single_store
        import_result = nil
        begin
          case @store.store_type
          when 'Shipstation'
          	handler = Groovepacker::Stores::Handlers::ShipstationHandler.new(@store)
          end
          context = Groovepacker::Stores::Context.new(handler)
          import_result = context.import_images
        rescue Exception => e
          @result['status'] = false
          @result['messages'].push(e.message)
        end
        return import_result
      end
  end
end
