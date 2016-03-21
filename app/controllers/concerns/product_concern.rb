module ProductConcern
  extend ActiveSupport::Concern
  
  included do
    before_filter :groovepacker_authorize!
    before_filter :init_result_obj, only: [:update]
    include ProductsHelper
    include Groovepacker::Orders::ResponseMessage
  end
  
  private
    def gp_products_module
      Groovepacker::Products::Products.new(result: @result, params_attrs: params, current_user: current_user, session: session)
    end

    def init_result_obj
      @result = { 'status' => true, 'messages' => [] }
    end
end
