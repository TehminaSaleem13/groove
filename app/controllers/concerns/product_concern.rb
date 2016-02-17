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
      Groovepacker::Products::Products.new(result: @result, params_attrs: params, current_user: current_user)
    end

    def init_result_obj
      @result = { 'status' => true, 'messages' => [] }
    end

    def initialize_result
      result = {}
      result['status'] = true
      result['messages'] = []
      return result
    end

    def generate_csv(result)
      products = list_selected_products(params)
      result['filename'] = 'products-'+Time.now.to_s+'.csv'
      CSV.open("#{Rails.root}/public/csv/#{result['filename']}", "w") do |csv|
        ProductsHelper.products_csv(products, csv)
      end
      return result
    end

    def generate_error_csv(result)
      result['filename'] = 'error.csv'
      CSV.open("#{Rails.root}/public/csv/#{result['filename']}", "w") do |csv|
        csv << result['messages']
      end
      return result
    end
end
