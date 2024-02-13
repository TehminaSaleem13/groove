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
      order = client.get_single_order('1001')

      expect(order).not_to be_nil
    end
  end

  describe 'Products' do
    it 'retrieves a product against an ID from shopline store' do
      product = client.product('16063158007488155566820780')

      expect(product).not_to be_nil
    end

    it 'retrieves a variant against an ID from shopline store' do
      variant = client.get_variant('18063158007493524276030780')

      expect(variant).not_to be_nil
    end
  end
end
