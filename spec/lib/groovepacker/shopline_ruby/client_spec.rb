# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Groovepacker::ShoplineRuby::Client do
  let(:shopline_credential) { create(:store, :shopline).shopline_credential }
  let(:client) { described_class.new(shopline_credential) }

  describe 'Orders' do
    it 'retrieves orders from shopline store' do
      orders = client.orders

      expect(orders.count).to be >=1
    end

    it 'retrieves an order against an ID from shopline store' do
      order = client.get_single_order('SHOPLINE-1001')

      expect(order).not_to be_nil
    end
  end

  describe 'Products' do
    it 'retrieves a product against an ID from shopline store' do
      product = client.product('16061957704033459336032600')

      expect(product).to have_key('id')
      expect(product['id']).not_to be_empty
    end

    it 'retrieves a variant against an ID from shopline store' do
      variant = client.get_variant('18061957704037150323622600')

      expect(variant).to have_key('id')
    end
  end
end
