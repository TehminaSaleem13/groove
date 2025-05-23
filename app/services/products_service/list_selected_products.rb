# frozen_string_literal: true

module ProductsService
  class ListSelectedProducts < ProductsService::Base
    include ProductsHelper

    attr_accessor :params, :include_association

    def initialize(params, include_association = true)
      @params = params
      @include_association = include_association
    end

    def call
      result = if select_all_with_inverted?
                 if search?
                   do_search(params)
                 else
                   do_getproducts(params)
                 end
               else
                 params[:productArray]
               end

      generate_result(result)
    end

    private

    def generate_result(result)
      result_rows = []
      if inverted_and_has_products?
        find_result_rows(result)
      else
        result.each do |single_product|
          result_rows.push('id' => single_product['id'])
        end
      end

      result_rows = result_rows.presence || []
      p_ids = result_rows.map { |p| p['id'] }
      products = Product.where('id IN (?)', p_ids)
      preload_associations(products) if include_association
      products
    end

    def find_result_rows(result)
      not_in = []
      result_rows = []
      params[:productArray].each do |product|
        not_in.push(product['id'])
      end
      result.each do |single_product|
        result_rows.push('id' => single_product['id']) unless not_in.include? single_product['id']
      end
    end

    def inverted_and_has_products?
      params[:inverted].to_b && params[:productArray].present?
    end

    def select_all_with_inverted?
      params[:select_all] || params[:inverted]
    end

    def search?
      params[:search].present?
    end
  end
end
