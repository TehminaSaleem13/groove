require 'rails_helper'

describe Groovepacker::Stores::Importers::ShipstationRest::OrdersImporterNew do
  let(:store) { create(:store, store_type: 'Shipstation API 2') }
  let(:credential) { 
    create(:shipstation_rest_credential, 
      store: store,
      api_key: 'test_key',
      api_secret: 'test_secret'
    )
  }
  let(:import_item) { create(:import_item, store: store) }
  let(:ss_service) { double('Service') }
  let(:ss_response) { double('Response', parsed_response: [{ 'userName' => 'user1' }]) }
  let(:users) { [create(:user, username: 'user1')] }
  let(:api_key) { 'test_api_key' }
  let(:some_other_param) { 'test_param' }
  let(:yet_another_param) { 'another_test_value' }
  let(:handler) { double('Handler') }

  let(:importer) { described_class.new(handler) }

  before do
    importer.instance_variable_set(:@credential, credential)
    allow(Groovepacker::ShipstationRuby::Rest::Service)
      .to receive(:new)
      .and_return(ss_service)

    allow(ss_service)
      .to receive(:query)
      .with('/users?showInactive=false', nil, 'get')
      .and_return(ss_response)

    allow(Apartment::Tenant).to receive(:current).and_return('test_tenant')
    allow(Apartment::Tenant).to receive(:switch!)

    allow(User).to receive(:order).with(:username).and_return(users)
  end

  describe '#fetch_ss_and_gp_user_list' do
    it 'fetches ShipStation users' do
      importer.send(:fetch_ss_and_gp_user_list)
      expect(importer.instance_variable_get(:@ss_user_list).map { |user| user['userName'] }).to eq(['user1'])
    end

    it 'fetches GroovePacker users' do
      importer.send(:fetch_ss_and_gp_user_list)
      expect(importer.instance_variable_get(:@gp_user_list))
        .to eq([{ id: users.first.id, username: users.first.username }])
    end

    it 'handles tenant switching' do
      expect(Apartment::Tenant).to receive(:switch!).with('test_tenant')
      importer.send(:fetch_ss_and_gp_user_list)
    end
  end

  describe '#add_gp_user_id_in_ss_user_list' do
    context 'when both lists have matching users' do
      before do
        importer.instance_variable_set(:@ss_user_list, [{ 'userName' => 'user1' }])
        importer.instance_variable_set(:@gp_user_list, [{ id: 1, username: 'user1' }])
      end

      it 'adds gp_user_id to matching users' do
        importer.send(:add_gp_user_id_in_ss_user_list)
        expect(importer.instance_variable_get(:@ss_user_list).first['gp_user_id']).to eq(1)
      end
    end

    context 'when users do not match' do
      before do
        importer.instance_variable_set(:@ss_user_list, [{ 'userName' => 'nonexistent' }])
        importer.instance_variable_set(:@gp_user_list, [{ id: 1, username: 'user1' }])
      end

      it 'sets nil for non-matching users' do
        importer.send(:add_gp_user_id_in_ss_user_list)
        expect(importer.instance_variable_get(:@ss_user_list).first['gp_user_id']).to be_nil
      end
    end

    context 'when ss_user_list is nil' do
      before do
        importer.instance_variable_set(:@ss_user_list, nil)
        importer.instance_variable_set(:@gp_user_list, [{ id: 1, username: 'user1' }])
      end

      it 'handles nil ss_user_list gracefully' do
        expect { importer.send(:add_gp_user_id_in_ss_user_list) }.not_to raise_error
      end
    end

    context 'when gp_user_list is nil' do
      before do
        importer.instance_variable_set(:@ss_user_list, [{ 'userName' => 'user1' }])
        importer.instance_variable_set(:@gp_user_list, nil)
      end

      it 'handles nil gp_user_list gracefully' do
        importer.send(:add_gp_user_id_in_ss_user_list)
        expect(importer.instance_variable_get(:@ss_user_list).first['gp_user_id']).to be_nil
      end
    end
  end
end
