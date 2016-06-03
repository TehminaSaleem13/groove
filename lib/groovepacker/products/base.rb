module Groovepacker
  module Products
    class Base
      include ProductsHelper
      include Groovepacker::Orders::ResponseMessage

      def initialize(params={})
        @result = params[:result]
        @params = params[:params_attrs] || params[:params]
        @current_user = params[:current_user]
        @session = params[:session]
        @store = params[:store]
      end

      private
      	
    end
  end
end
