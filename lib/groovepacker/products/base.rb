module Groovepacker
  module Products
    class Base
      include ProductsHelper
      include Groovepacker::Orders::ResponseMessage

      def initialize(params={})
        @result = params[:result]
        @params = params[:params_attrs]
        @current_user = params[:current_user]
      end

      private
      	
    end
  end
end
