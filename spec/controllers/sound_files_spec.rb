require 'rails_helper'

RSpec.describe SoundFilesController, type: :controller do
  let(:tenant) { create(:tenant) }
  let(:valid_sound_type) { 'order_done' }
  let(:invalid_sound_type) { 'invalid_type' }
  let(:file_paths) { ['file1.mp3', 'file2.mp3'] }  
  let(:content_type) { 'audio/mpeg' }
  let(:privacy) { :public_read }

  def json_response
    JSON.parse(response.body)
  end

  describe 'POST #create_sounds' do
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
          file_paths: file_paths,  # File paths expected by the controller
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

  describe 'POST #remove_sounds' do
    context 'when successful' do
      it 'removes sounds and returns success' do
        allow(GroovS3).to receive(:delete_object_sound).and_return(true)

        post :remove_sounds, params: {
          file_names: file_paths,  # Assuming file_paths corresponds to file names
          sound_type: valid_sound_type
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['status']).to eq(true)
        expect(json_response['message']).to eq('Files deleted successfully')
      end
    end

    context 'when some files fail to delete' do
      it 'returns failure status and failed files' do
        allow(GroovS3).to receive(:delete_object_sound).and_return(false)  # Simulate failed deletion

        post :remove_sounds, params: {
          file_names: file_paths,  # Assuming file_paths corresponds to file names
          sound_type: valid_sound_type
        }

        expect(response).to have_http_status(:ok)
        expect(json_response['status']).to eq(false)
        expect(json_response['failed_files']).to eq(file_paths)
      end
    end
  end
end
