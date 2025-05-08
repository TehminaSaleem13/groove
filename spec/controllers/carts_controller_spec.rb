require 'rails_helper'

RSpec.describe CartsController, type: :controller do
  let(:valid_cart_attributes) do
    {
      cart_name: "Test Cart",
      cart_id: "C01",
      number_of_totes: 5,
      cart_rows: [
        { 
          row_name: "A", 
          row_count: 5,
          default_width: 10.0,
          default_height: 8.0,
          default_length: 2.0
        }
      ]
    }
  end

  before do
    allow(controller).to receive(:groovepacker_authorize!).and_return(true)
  end

  describe "GET #index" do
    let!(:cart) { create(:cart) }
    let!(:cart_row) { create(:cart_row, cart: cart) }
    let!(:cart_tote) { create(:cart_tote, cart_row: cart_row, tote_id: "#{cart_row.row_name}-1") }

    it "returns a successful response" do
      get :index, format: :json
      expect(response).to be_successful
    end

    it "returns all carts with their rows" do
      get :index, format: :json
      body = JSON.parse(response.body)
      expect(body.first["cart_rows"]).to be_present
    end

    it "includes cart_totes in the response" do
      get :index, format: :json
      body = JSON.parse(response.body)
      expect(body.first["cart_rows"].first["cart_totes"]).to be_present
    end
  end

  describe "GET #show" do
    let!(:cart) { create(:cart) }
    let!(:cart_row) { create(:cart_row, cart: cart) }
    let!(:cart_tote) { create(:cart_tote, cart_row: cart_row, tote_id: "#{cart_row.row_name}-1") }

    it "returns a successful response" do
      get :show, params: { id: cart.id }, format: :json
      expect(response).to be_successful
    end

    it "returns the requested cart with its rows" do
      get :show, params: { id: cart.id }, format: :json
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(cart.id)
      expect(body["cart_rows"]).to be_present
    end

    it "returns the requested cart with its rows and totes" do
      get :show, params: { id: cart.id }, format: :json
      body = JSON.parse(response.body)
      expect(body["cart_rows"].first["cart_totes"]).to be_present
      expect(body["cart_rows"].first["cart_totes"].first["tote_id"]).to eq("#{cart_row.row_name}-1")
    end
  end

  describe "POST #create" do
    context "with valid parameters" do
      it "creates a new cart" do
        expect {
          post :create, params: valid_cart_attributes, format: :json
        }.to change(Cart, :count).by(1)
      end

      it "creates associated cart rows" do
        expect {
          post :create, params: valid_cart_attributes, format: :json
        }.to change(CartRow, :count).by(1)
      end

      it "creates associated cart totes" do
        expect {
          post :create, params: valid_cart_attributes, format: :json
        }.to change(CartTote, :count).by(5)
      end

      it "assigns correct tote_id values to cart totes" do
        post :create, params: valid_cart_attributes, format: :json
        cart = Cart.last
        totes = cart.cart_rows.first.cart_totes
        
        expect(totes.count).to eq(5)
        expect(totes.map(&:tote_id)).to match_array(["A-1", "A-2", "A-3", "A-4", "A-5"])
      end

      it "assigns dimensions to cart totes" do
        post :create, params: valid_cart_attributes, format: :json
        cart = Cart.last
        tote = cart.cart_rows.first.cart_totes.first
        
        expect(tote.width).to eq(10.0)
        expect(tote.height).to eq(8.0)
        expect(tote.length).to eq(2.0)
      end

      it "returns the created cart with rows" do
        post :create, params: valid_cart_attributes, format: :json
        body = JSON.parse(response.body)
        expect(body["cart_name"]).to eq("Test Cart")
        expect(body["cart_rows"]).to be_present
      end
    end

    context "with invalid parameters" do
      let(:invalid_attributes) do
        { data: { cart_name: nil, cart_id: "C01", number_of_totes: 5 } }
      end

      it "does not create a new cart" do
        expect {
          post :create, params: invalid_attributes, format: :json
        }.not_to change(Cart, :count)
      end

      it "returns unprocessable entity status" do
        post :create, params: invalid_attributes, format: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PUT #update" do
    let!(:cart) { create(:cart) }
    let!(:cart_row) { create(:cart_row, cart: cart) }
    
    before do
      5.times do |i|
        create(:cart_tote, 
          cart_row: cart_row,
          tote_id: "#{cart_row.row_name}-#{i+1}",
          width: 5.0,
          height: 5.0,
          length: 1.0
        )
      end
    end

    context "with valid parameters" do
      let(:update_attributes) do
        {
          id: cart.id,
          cart_name: "Updated Cart",
          cart_id: cart.cart_id,
          number_of_totes: 6,
          cart_rows: [
            { 
              row_name: "B", 
              row_count: 6,
              default_width: 12.0,
              default_height: 10.0,
              default_length: 3.0
            }
          ]
        }
      end

      it "updates the cart" do
        put :update, params: update_attributes, format: :json
        cart.reload
        expect(cart.cart_name).to eq("Updated Cart")
      end

      it "updates cart rows" do
        put :update, params: update_attributes, format: :json
        cart.reload
        expect(cart.cart_rows.first.row_name).to eq("B")
      end

      it "recreates cart totes with correct IDs" do
        put :update, params: update_attributes, format: :json
        cart.reload
        
        totes = cart.cart_rows.first.cart_totes
        expect(totes.count).to eq(6)
        expect(totes.map(&:tote_id)).to match_array(["B-1", "B-2", "B-3", "B-4", "B-5", "B-6"])
      end
      
      it "sets correct dimensions on cart totes" do
        put :update, params: update_attributes, format: :json
        cart.reload
        
        tote = cart.cart_rows.first.cart_totes.first
        expect(tote.width).to eq(12.0)
        expect(tote.height).to eq(10.0)
        expect(tote.length).to eq(3.0)
      end

      it "updates the total number of totes" do
        put :update, params: update_attributes, format: :json
        cart.reload
        expect(cart.number_of_totes).to eq(6)
      end
    end

    context "with invalid parameters" do
      let(:invalid_update_attributes) do
        {
          id: cart.id,
          data: { cart_name: nil }
        }
      end

      it "returns unprocessable entity status" do
        put :update, params: invalid_update_attributes, format: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:cart) { create(:cart) }
    let!(:cart_row) { create(:cart_row, cart: cart) }
    let!(:cart_tote) { create(:cart_tote, cart_row: cart_row) }

    it "destroys the cart" do
      expect {
        delete :destroy, params: { id: cart.id }, format: :json
      }.to change(Cart, :count).by(-1)
    end

    it "destroys associated cart rows" do
      expect {
        delete :destroy, params: { id: cart.id }, format: :json
      }.to change(CartRow, :count).by(-1)
    end

    it "destroys associated cart totes" do
      expect {
        delete :destroy, params: { id: cart.id }, format: :json
      }.to change(CartTote, :count).by(-1)
    end

    it "returns no content status" do
      delete :destroy, params: { id: cart.id }, format: :json
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'GET #print_tote_labels' do
    let!(:cart) { create(:cart, cart_name: 'Cart 1', cart_id: 'C01', number_of_totes: 10) }
    let!(:cart_row) { create(:cart_row, cart: cart, row_name: 'A', row_count: 2) }
  
    before do
      puts "Cart ID in test: #{cart.id}, Cart ID field: #{cart.cart_id}"
    end

    it 'returns a PDF with tote labels' do
      get :print_tote_labels, params: { id: cart.cart_id }, format: :pdf

      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to include('application/pdf')
    end
  end

end
