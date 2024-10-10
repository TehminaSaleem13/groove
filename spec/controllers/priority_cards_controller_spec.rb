require 'rails_helper'

RSpec.describe PriorityCardsController, type: :controller do
  before do
    Groovepacker::SeedTenant.new.seed
    inv_wh = FactoryBot.create(:inventory_warehouse, is_default: true)
    @store = FactoryBot.create(:store, inventory_warehouse_id: inv_wh.id)
    @user = FactoryBot.create(:user, username: 'scan_pack_spec_user', name: 'Scan Pack user', role: Role.find_by_name('Scan & Pack User'))
  end

  let!(:order_tag1) { OrderTag.create(name: 'Tag1') }
  let!(:order_tag2) { OrderTag.create(name: 'Tag2') }
  let!(:duplicate_tag) { OrderTag.create(name: 'Tag1') }
  let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }
  let(:origin_store) { create(:origin_store, store: @store) }

  let(:valid_attributes) do
    {
      priority_name: 'high',
      tag_color: '#FF0000',
      is_card_disabled: false,
      assigned_tag: 'BATCHED'
    }
  end

  let(:invalid_attributes) do
    {
      priority_name: '',
      tag_color: '#FF0000',
      is_card_disabled: false,
      assigned_tag: 'BATCHED'
    }
  end

  let(:priority_card) { PriorityCard.create!(valid_attributes) }
  
  describe 'GET #index' do
    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'returns a success response' do
      priority_card
      get :index
      expect(response).to be_successful
      expect(JSON.parse(response.body).length).to eq(1)
    end

    it 'ensures the regular card exists' do
      allow(controller).to receive(:ensure_regular_card).and_call_original
      get :index
      expect(controller).to have_received(:ensure_regular_card)
    end
  end

  describe 'GET #show' do
    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'returns a success response' do
      get :show, params: { id: priority_card.to_param }
      expect(response).to be_successful
    end

    it 'returns the correct priority card' do
      get :show, params: { id: priority_card.to_param }
      expect(JSON.parse(response.body)['id']).to eq(priority_card.id)
    end
  end

  describe 'POST #create' do
    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    context 'with valid params' do
      it 'creates a new PriorityCard' do
        expect do
          post :create, params: { priority_card: valid_attributes }
        end.to change(PriorityCard, :count).by(1)
      end

      it 'renders a JSON response with the new priority card' do
        post :create, params: { priority_card: valid_attributes }
        expect(response).to have_http_status(:created)
        expect(response.content_type).to include('application/json')
      end
    end

    context 'with invalid params' do
      it 'renders a JSON response with errors' do
        post :create, params: { priority_card: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to include('application/json')
      end
    end
  end

  describe 'PUT #update' do
    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    context 'with valid params' do
      let(:new_attributes) do
        {
          priority_name: 'medium',
          tag_color: '#00FF00',
          assigned_tag: 'PROCESSED'
        }
      end

      it 'updates the requested priority card' do
        put :update, params: { id: priority_card.to_param, priority_card: new_attributes }
        priority_card.reload
        expect(priority_card.priority_name).to eq('medium')
        expect(priority_card.tag_color).to eq('#00FF00')
        expect(priority_card.assigned_tag).to eq('PROCESSED')
      end

      it 'renders a JSON response with the updated priority card' do
        put :update, params: { id: priority_card.to_param, priority_card: valid_attributes }
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')
      end
    end

    context 'with invalid params' do
      it 'renders a JSON response with errors' do
        put :update, params: { id: priority_card.to_param, priority_card: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to include('application/json')
      end
    end

    it 'handles RecordNotFound exception' do
      put :update, params: { id: priority_card.to_param, priority_card: "" }
      expect(JSON.parse(response.body)['error'])
    end
  end

  describe 'DELETE #destroy' do
    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end

    it 'destroys the requested priority card' do
      priority_card
      expect do
        delete :destroy, params: { id: priority_card.to_param }
      end.to change(PriorityCard, :count).by(-1)
    end
  end

  describe 'calculate_tagged_count method' do
    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end
  
    it 'calculates the correct count of awaiting orders for a tag' do
      order_tag = OrderTag.create!(name: 'BATCHED')
      expect(controller.send(:calculate_tagged_count, 'BATCHED')).to eq(0)
    end
  end
end
