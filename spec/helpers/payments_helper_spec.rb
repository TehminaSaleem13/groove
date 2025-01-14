# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentsHelper do
  let(:current_tenant) { 'tenant_1' }
  let(:customer) { instance_double("Customer", default_card: nil, id: 'cus_123') }
  let(:card_source) { double('CardSource', id: 'card_123', object: 'card') }
  let(:bank_account_source) { double('BankAccountSource', id: 'bank_123', object: 'bank_account') }
  let(:card_info) { { last4: '4242', exp_month: 12, exp_year: 2025, cvc: '123' } }
  let(:bank_info) { { account_holder_name: 'John Doe', account_holder_type: 'individual', routing_number: '110000000', account_number: '1234567890', country: 'US' } }
  let(:token) { double('Token', id: 'tok_123') }
  let(:source) { double('Source', id: 'src_123', cvc_check: 'pass', status: 'verified') }

  before do
    allow(helper).to receive(:get_current_customer).with(current_tenant).and_return(customer)
    allow(Stripe::Customer).to receive(:list_sources).with(customer.id, object: 'card').and_return([card_source])
    allow(Stripe::Customer).to receive(:list_sources).with(customer.id, object: 'bank_account').and_return([bank_account_source])
    allow(Stripe::Customer).to receive(:create_source).with(customer.id, source: token.id).and_return(source)
  end

  describe '#card_bank_list' do
    it 'populates the cards and bank accounts' do
      helper.card_bank_list(current_tenant)

      expect(helper.instance_variable_get('@result')['cards']).to eq([card_source])
      expect(helper.instance_variable_get('@result')['bank_accounts']).to eq([bank_account_source])
    end

    it 'returns an empty array if there are no card or bank account sources' do
      allow(Stripe::Customer).to receive(:list_sources).with(customer.id, object: 'card').and_return([])
      allow(Stripe::Customer).to receive(:list_sources).with(customer.id, object: 'bank_account').and_return([])

      helper.card_bank_list(current_tenant)

      expect(helper.instance_variable_get('@result')['cards']).to eq([])
      expect(helper.instance_variable_get('@result')['bank_accounts']).to eq([])
    end

    it 'does not populate cards and bank accounts if the customer is nil' do
      allow(helper).to receive(:get_current_customer).with(current_tenant).and_return(nil)

      helper.card_bank_list(current_tenant)

      expect(helper.instance_variable_get('@result')['cards']).to eq([])
      expect(helper.instance_variable_get('@result')['bank_accounts']).to eq([])
    end
  end

  describe '#add_card_bank_details' do
    context 'when adding a card' do

      it 'Creates a new card' do
        helper.add_card_bank_details(card_info, current_tenant)
        expect(response.status).to eq(200)
      end

      it 'handles card creation failure with error message' do
        allow(Stripe::Customer).to receive(:create_source).and_raise(Stripe::CardError.new("The card number is not a valid credit card number.", nil))

        helper.add_card_bank_details(card_info, current_tenant)
        expect(helper.instance_variable_get('@result')['status']).to eq(false)
        expect(helper.instance_variable_get('@result')['messages']).to include('The card number is not a valid credit card number.')
      end
    end
    context 'when adding a bank account' do
      it 'creates a new bank account ' do
        helper.add_card_bank_details(bank_info, current_tenant)
        expect(response.status).to eq(200)
      end

      it 'handles bank account creation failure with error message' do
        allow(Stripe::Customer).to receive(:create_source).and_raise(Stripe::StripeError.new('You must supply either a card, customer, PII data, bank account'))
        helper.add_card_bank_details(bank_info, current_tenant)
        expect(helper.instance_variable_get('@result')['status']).to eq(false)
        expect(helper.instance_variable_get('@result')['messages'].first).to include('You must supply either a card, customer, PII data, bank account')
      end
    end
  end

  describe '#make_default_card' do
    it 'does nothing if no customer is found' do
      allow(helper).to receive(:get_current_customer).with(current_tenant).and_return(nil)

      helper.make_default_card(card_source.id, current_tenant)

      expect(customer.default_card).to be_nil
    end
  end

  describe '#get_default_card' do
    it 'returns the default card if one exists' do
      allow(customer).to receive(:default_source).and_return(card_source)

      helper.get_default_card(current_tenant)

      expect(helper.instance_variable_get('@result')['default_card']).to eq(card_source)
    end

    it 'returns nil if no default card exists' do
      allow(customer).to receive(:default_source).and_return(nil)

      helper.get_default_card(current_tenant)

      expect(helper.instance_variable_get('@result')['default_card']).to be_nil
    end
  end

  describe '#delete_a_card' do
    it 'deletes an existing card' do
      allow(Stripe::Customer).to receive(:retrieve_source).and_return(card_source)
      allow(card_source).to receive(:delete).and_return(true)

      helper.delete_a_card(card_source.id, current_tenant)

      expect(card_source).to have_received(:delete)
    end

    it 'does nothing if the card is not found' do
      allow(Stripe::Customer).to receive(:retrieve_source).and_return(nil)

      helper.delete_a_card(card_source.id, current_tenant)

      expect(helper.instance_variable_get('@result')['status']).to eq(true)
    end
  end

  describe '#get_plan_info' do
    it 'returns the plan information when the plan ID is valid' do
      plan = double('Plan', id: 'plan_123', name: 'Groove 100')
      allow(Stripe::Plan).to receive(:retrieve).and_return(plan)

      result = helper.get_plan_info('plan_123')

      expect(result['status']).to eq(true)
      expect(result['plan_info'].id).to eq('plan_123')
    end

    it 'returns an error message when the plan ID is invalid' do
      allow(Stripe::Plan).to receive(:retrieve).and_raise(Stripe::InvalidRequestError.new('Invalid plan ID', 'param'))

      result = helper.get_plan_info('invalid_plan')

      expect(result['status']).to eq(false)
      expect(result['messages']).to include('Invalid plan ID')
    end
  end

  describe '#card_details' do

    context 'when the CVC is correct' do
      before do
        allow(Stripe::Customer).to receive(:update_source).and_return(true)
        allow(Stripe::Customer).to receive(:update).and_return(true)
      end

      it 'updates the customer with the new card source' do
        expect(helper.card_details(source, customer)).to be true
        expect(Stripe::Customer).to have_received(:update_source).with(customer.id, source.id)
      end
    end

    context 'when the CVC is incorrect' do
      before do
        allow(source).to receive(:cvc_check).and_return(false)
        allow(source).to receive(:delete)
      end

      it 'deletes the source and fails' do
        helper.create_result_hash
        helper.card_details(source, customer)
        expect(source).to have_received(:delete)
        expect(helper.instance_variable_get(:@result)['status']).to be_falsey
        expect(helper.instance_variable_get(:@result)['messages']).to include('The CVC entered is not correct. Modify it.')
      end
    end

    context 'when updating the customer fails' do
      before do
        allow(source).to receive(:cvc_check).and_return('pass')
        allow(Stripe::Customer).to receive(:update_source).and_return(false)
      end

      it 'fails with an appropriate message' do
        helper.create_result_hash
        helper.card_details(source, customer)
        expect(helper.instance_variable_get(:@result)['status']).to be_falsey
        expect(helper.instance_variable_get(:@result)['messages']).to include('The card could not be created because of server problem')
      end
    end
  end

  describe '#bank_details' do
    context 'when the bank account is verified' do
      it 'sets the default source and updates the customer' do
        allow(source).to receive(:verify).with(amounts: [32, 45])
        allow(Stripe::Customer).to receive(:update).with(customer.id, default_source: source.id).and_return(true)

        helper.create_result_hash
        helper.bank_details(source, customer)

        expect(helper.instance_variable_get('@result')['status']).to eq(true)
      end
    end
  end
end
