require 'rails_helper'

RSpec.describe SoundFilesController, type: :controller do
  let(:tenant) { create(:tenant) }
  let(:valid_sound_type) { 'order_done' }
  let(:invalid_sound_type) { 'invalid_type' }
  let(:file_paths) { ['file1.mp3', 'file2.mp3'] }
  let(:content_type) { 'audio/mpeg' }
  let(:privacy) { :public_read }

  before do
    Groovepacker::SeedTenant.new.seed
    generalsetting = GeneralSetting.all.first
    generalsetting.update_column(:inventory_tracking, true)
    generalsetting.update_column(:hold_orders_due_to_inventory, true)
    user_role = FactoryBot.create(:role, name: 'csv_spec_tester_role', add_edit_stores: true, import_products: true)
    @user = FactoryBot.create(:user, name: 'CSV Tester', username: 'csv_spec_tester', role: user_role)
    access_restriction = FactoryBot.create(:access_restriction)
  end

  after do
    @tenant.destroy if @tenant
  end

  def json_response
    JSON.parse(response.body)
  end

  describe 'POST #create_sounds' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      allow(token1).to receive(:id).and_return(nil)
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end
    context 'when successful' do
      it 'creates sounds and returns success' do
        allow(GroovS3).to receive(:create_sound_from_system).and_return(['url1', 'url2'])

        post :create_sounds, params: {
          sound_type: valid_sound_type,
          file_paths: file_paths,
          content_type: content_type,
          privacy: privacy
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['status']).to eq('success')
        expect(json_response['urls']).to eq(['url1', 'url2'])
      end
    end

    context 'when an error occurs' do
      it 'returns an error message' do
        allow(GroovS3).to receive(:create_sound_from_system).and_raise(StandardError.new("Something went wrong"))

        post :create_sounds, params: {
          sound_type: valid_sound_type,
          file_paths: file_paths,
          content_type: content_type,
          privacy: privacy
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['status']).to eq('error')
        expect(json_response['message']).to eq('Something went wrong')
      end
    end
  end

  describe 'GET #get_sounds_files' do
    let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

    before do
      allow(controller).to receive(:doorkeeper_token) { token1 }
      allow(token1).to receive(:id).and_return(nil)
      header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
      @request.headers.merge! header
    end
    context 'when successful' do
      it 'returns the sounds' do
        allow(GroovS3).to receive(:get_sounds_export).and_return({ 'correct_scan' => 'url1', 'error_scan' => 'url2' })

        get :get_sounds_files
        expect(response).to have_http_status(:ok)
        expect(json_response['status']).to eq('success')
        expect(json_response['sounds']).to eq({ 'correct_scan' => 'url1', 'error_scan' => 'url2' })
      end
    end

    context 'when an error occurs' do
      it 'returns an error message' do
        allow(GroovS3).to receive(:get_sounds_export).and_raise(StandardError.new("Failed to fetch sounds"))

        get :get_sounds_files
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['status']).to eq('error')
        expect(json_response['message']).to eq('Failed to fetch sounds')
      end
    end
  end
  
end
