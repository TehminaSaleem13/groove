# frozen_string_literal: true

class FixProductData
  def initialize(params)
    @params = params
  end

  def call
    tenants_list = @params[:select_all] ? Tenant.all : Tenant.where(name: @params[:tenant_names])

    tenants_list.find_each do |tenant|
      Apartment::Tenant.switch! tenant.name
      # Deleting Blank Barcodes
      ProductBarcode.left_joins(:product).merge(Product.where(id: nil)).delete_all
      # Deleting Blank Skus
      ProductSku.left_joins(:product).merge(Product.where(id: nil)).delete_all
    end
  end
end
