# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Groovepacker::VeeqoRuby::Client do
  let(:veeqo_credential) { create(:store, :veeqo).veeqo_credential }
  let(:client) { described_class.new(veeqo_credential) }

  describe 'Orders' do
    it 'retrieves orders from veeqo store' do
      orders = client.orders(nil, 'awaiting_fulfillment')
      expect(orders.count).to be >=1
    end
  end
end
