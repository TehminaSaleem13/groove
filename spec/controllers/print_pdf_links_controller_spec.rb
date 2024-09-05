# spec/controllers/print_pdf_links_controller_spec.rb

require 'rails_helper'

RSpec.describe PrintPdfLinksController, type: :controller do
  let(:token1) { instance_double('Doorkeeper::AccessToken', acceptable?: true, resource_owner_id: @user.id) }

  before do
    user_role = FactoryBot.create(:role, name: 'csv_spec_tester_role', add_edit_stores: true, import_products: true,
                                         add_edit_order_items: true)
    @user = FactoryBot.create(:user, name: 'CSV Tester', username: 'csv_spec_tester', role: user_role)
    allow(controller).to receive(:doorkeeper_token) { token1 }
    header = { 'Authorization' => 'Bearer ' + FactoryBot.create(:access_token, resource_owner_id: @user.id).token }
    @request.headers.merge! header
  end

  describe 'POST #create' do
    it 'creates PDF links and returns JSON response' do
      # Create a JSON payload for testing
      json_payload = [
        { 'uri' => 'data:application/pdf;base64,PDF_DATA_1', 'name' => 'pdf1.pdf' },
        { 'uri' => 'data:application/pdf;base64,PDF_DATA_2', 'name' => 'pdf2.pdf' }
      ]

      post :create, params: { _json: json_payload }

      created_links = JSON.parse(response.body)
      expect(response).to have_http_status(:created)
    end
  end

  describe 'GET #get_pdf_list' do
    it 'returns a list of PDF links' do
      create(:print_pdf_link, pdf_name: 'pdf1.pdf', is_pdf_printed: false)
      create(:print_pdf_link, pdf_name: 'pdf2.pdf', is_pdf_printed: true)

      get :get_pdf_list

      expect(response).to have_http_status(:ok)

      pdf_links = JSON.parse(response.body)['pdfs']
      expect(pdf_links.size).to eq(2)
      expect(pdf_links[0]['pdf_name']).to eq('pdf1.pdf')
      expect(pdf_links[0]['is_pdf_printed']).to be_falsey
      expect(pdf_links[1]['pdf_name']).to eq('pdf2.pdf')
      expect(pdf_links[1]['is_pdf_printed']).to be_truthy
    end
  end

  describe 'PATCH #update_is_printed' do
    it 'updates is_pdf_printed attribute for a PDF link' do
      pdf_link = create(:print_pdf_link, pdf_name: 'pdf1.pdf', is_pdf_printed: false)
      put :update_is_printed, params: { id: pdf_link.id, url: pdf_link.url }

      expect(response).to have_http_status(:ok)

      expect(JSON.parse(response.body)['success']).to be_truthy

      # Reload the PDF link from the database to check the updated attribute
      pdf_link.reload
      expect(pdf_link.is_pdf_printed).to be_truthy
    end

    it 'returns a not found response if the PDF link does not exist' do
      put :update_is_printed, params: { id: 'null', url: 'nonexistent_url' }

      expect(response).to have_http_status(:not_found)

      expect(JSON.parse(response.body)['success']).to be_falsey
    end
  end
end
