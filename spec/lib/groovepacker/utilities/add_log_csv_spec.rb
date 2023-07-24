# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AddLogCsv do
  let(:tenant) { create(:tenant, name: Apartment::Tenant.current) }
  let(:csv_url_mock) { double('GroovS3', url: 'http://example.com/csv') }
  let(:stripe_customer) { double('Stripe::Customer', delinquent: false) }
  let(:subscription_plan) { double('sub_plan', amount: 1000) }
  let(:subscription_items) { [double('subsctiption_item', plan: subscription_plan)] }
  let(:stripe_subscription) { double('Stripe::Subscription', plan: subscription_plan, items: subscription_items ) }
  let(:stripe_invoice) { double('Stripe::Invoice', status: 'paid', created: 1.day.ago.to_i) }

  before do
    create(:subscription, tenant: tenant, status: 'completed', tenant_name: tenant.name)
    create(:access_restriction)

    allow(GroovS3).to receive(:create_public_csv).and_return(csv_url_mock)

    allow(Stripe::Customer).to receive(:retrieve).and_return(stripe_customer)

    allow(subscription_plan).to receive(:[]).with('amount').and_return(1000)

    allow(stripe_customer).to receive_message_chain(:subscriptions, :retrieve) { stripe_subscription }
    allow(stripe_customer).to receive_message_chain(:subscriptions, :data, :first) { stripe_subscription }

    allow(stripe_customer).to receive_message_chain(:subscriptions, :data, :first, :latest_invoice) { stripe_invoice }
    allow(Stripe::Invoice).to receive(:retrieve).and_return(stripe_invoice)

    allow(Stripe::SubscriptionItem).to receive(:list).and_return(subscription_items)
  end

  describe '.send_tenant_log' do
    context 'when subscription have plan' do
      it 'calls the deliver method on StripeInvoiceEmail' do
        stripe_email_mock = double('StripeInvoiceEmail', deliver: true)
        allow(StripeInvoiceEmail).to receive(:send_tenant_details).and_return(stripe_email_mock)
  
        described_class.new.send_tenant_log
  
        expect(stripe_email_mock).to have_received(:deliver)
      end
    end

    context 'when subscription does not have plan' do
      let(:stripe_subscription) { double('Stripe::Subscription', items: subscription_items, plan: nil) }

      it 'calls the deliver method on StripeInvoiceEmail' do
        stripe_email_mock = double('StripeInvoiceEmail', deliver: true)
        allow(StripeInvoiceEmail).to receive(:send_tenant_details).and_return(stripe_email_mock)
  
        described_class.new.send_tenant_log
  
        expect(stripe_email_mock).to have_received(:deliver)
      end
    end
  end
end
