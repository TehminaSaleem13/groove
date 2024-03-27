# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateTenant do
  describe '#create_tenant' do
    let(:subscription) { create(:subscription, tenant_name: Apartment::Tenant.current) }
    let(:instance) { described_class.new }

    before do
      # Database already exists
      allow(Apartment::Tenant).to receive(:create).with(subscription.tenant_name).and_return(true)
    end

    it 'seeds the tenant' do
      expect_any_instance_of(Groovepacker::SeedTenant).to receive(:seed).with(true,
                                                                              subscription.user_name,
                                                                              subscription.email,
                                                                              subscription.password).once.and_call_original
      instance.create_tenant(subscription)
    end
  end
end
