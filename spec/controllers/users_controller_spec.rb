require 'rails_helper'

RSpec.describe UsersController, :type => :controller do
  before(:each) do
    sup_ad = FactoryGirl.create(:role,:name=>'super_admin1',:make_super_admin=>true)
    @user_role = FactoryGirl.create(:role,:name=>'test_user_role', :add_edit_users => true, :add_edit_stores => true)
    @user = FactoryGirl.create(:user,:username=>"new_admin1", :role=>sup_ad)
    sign_in @user
    @access_restriction = FactoryGirl.create(:access_restriction)
    @inv_wh = FactoryGirl.create(:inventory_warehouse, :name=>'csv_inventory_warehouse')
    @store = FactoryGirl.create(:store, :name=>'csv_store', :store_type=>'CSV', :inventory_warehouse=>@inv_wh, :status => true)
    Delayed::Worker.delay_jobs = false
  end
  after(:each) do
    Delayed::Job.destroy_all
  end
  
  describe "Spec for Users signup" do
    it "Should not create a user and should return password mismach error (if passwords do not match)" do
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_users, true)
      @access_restriction.update_attribute(:num_users, 1)
      post :createUpdateUser, { :username => 'test_user', :password => '345678', :conf_password => '123456789', :role => {} }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(false)

    end

    it "Should create a user and should return confirmation_code" do
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_users, true)
      @access_restriction.update_attribute(:num_users, 1)
      post :createUpdateUser, { :username => 'test_user', :password => '12345678', :conf_password => '12345678', :role => {} }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['user']['confirmation_code']).to_not be_nil
    end

    it "Should update the user and should return activate/deactivate user" do
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_users, true)
      @access_restriction.update_attribute(:num_users, 1)
      post :createUpdateUser, { :username => 'test_user', :password => '12345678', :conf_password => '12345678', :role => {} }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['user']['confirmation_code']).to_not be_nil

      user = User.find_by_username('test_user')
      post :createUpdateUser, { :id => user.id, :username => user.username, :active => false, :role => {} }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['user']['active']).to eq(false)

      post :createUpdateUser, { :id => user.id, :username => user.username, :active => true, :role => {} }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['user']['active']).to eq(true)
    end

    it "Should return all the available roles" do
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_users, true)
      @access_restriction.update_attribute(:num_users, 1)
      get :get_roles, {}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['roles']).to_not match_array([])
    end

    it "Should update the user role to Super Admin" do
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_users, true)
      @access_restriction.update_attribute(:num_users, 1)
      post :createUpdateUser, { :username => 'test_user', :password => '12345678', :conf_password => '12345678', :role => {} }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['user']['confirmation_code']).to_not be_nil

      user = User.find_by_username('test_user')
      #s_admin_role = {"access_orders"=>true, "access_products"=>true, "access_scanpack"=>true, "access_settings"=>false, "add_edit_order_items"=>true, "add_edit_products"=>true, "add_edit_stores"=>false, "add_edit_users"=>false, "change_order_status"=>true, "create_backups"=>true, "create_edit_notes"=>true, "create_packing_ex"=>true, "custom"=>false, "delete_products"=>false, "display"=>true, "edit_general_prefs"=>false, "edit_packing_ex"=>false, "edit_scanning_prefs"=>false, "id"=>82, "import_orders"=>true, "import_products"=>false, "make_super_admin"=>false, "name"=>"Manager", "restore_backups"=>false, "view_packing_ex"=>true}
      post :createUpdateUser, { :id => user.id, :username => user.username, :active => true, :role => {:name => "Super Admin", :make_super_admin=>true} }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['user']['active']).to eq(true)
      expect(result['user']['role_id']).to_not be_nil
      expect(result['user']['role']).to_not  match_array([])
      role = result['user']['role']
      expect(role['add_edit_order_items']).to be(true)
      expect(role['import_orders']).to be(true)
      expect(role['change_order_status']).to be(true)
      expect(role['create_edit_notes']).to be(true)
      expect(role['view_packing_ex']).to be(true)
      expect(role['create_packing_ex']).to be(true)
      expect(role['edit_packing_ex']).to be(true)
      expect(role['delete_products']).to be(true)
      expect(role['import_products']).to be(true)
      expect(role['add_edit_products']).to be(true)
      expect(role['add_edit_users']).to be(true)
      expect(role['make_super_admin']).to be(true)
      expect(role['access_scanpack']).to be(true)
      expect(role['access_orders']).to be(true)
      expect(role['access_products']).to be(true)
      expect(role['access_settings']).to be(true)
      expect(role['edit_general_prefs']).to be(true)
      expect(role['edit_scanning_prefs']).to be(true)
      expect(role['add_edit_stores']).to be(true)
      expect(role['create_backups']).to be(true)
      expect(role['restore_backups']).to be(true)
    end


    it "Should update the user role to 'Scan & Pack User'" do
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_users, true)
      @access_restriction.update_attribute(:num_users, 1)
      post :createUpdateUser, { :username => 'test_user', :password => '12345678', :conf_password => '12345678', :role => {} }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['user']['confirmation_code']).to_not be_nil

      user = User.find_by_username('test_user')
      #s_admin_role = {:access_orders => true, :access_products => true, :access_scanpack => true, :access_settings =>true, :add_edit_order_items => true, :add_edit_products => true, :add_edit_stores => true, :add_edit_users => true, :change_order_status => true, :create_backups => true, :create_edit_notes => true, :create_packing_ex => true, :custom => false, :delete_products => true, :display => true, :edit_general_prefs => true, :edit_packing_ex => true, :edit_scanning_prefs => true, :import_orders => true, :import_products => true, :make_super_admin => true, :name => "Super Admin", :restore_backups => true, :view_packing_ex => true}
      post :createUpdateUser, { :id => user.id, :username => user.username, :active => true, :role => {:name => "Scan & Pack User", :scan_and_pack_user=>true} }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['user']['active']).to eq(true)
      expect(result['user']['role_id']).to_not be_nil
      expect(result['user']['role']).to_not  match_array([])
      role = result['user']['role']
      expect(role['add_edit_order_items']).to be(false)
      expect(role['import_orders']).to be(false)
      expect(role['change_order_status']).to be(false)
      expect(role['create_edit_notes']).to be(false)
      expect(role['view_packing_ex']).to be(false)
      expect(role['create_packing_ex']).to be(false)
      expect(role['edit_packing_ex']).to be(false)
      expect(role['delete_products']).to be(false)
      expect(role['import_products']).to be(false)
      expect(role['add_edit_products']).to be(false)
      expect(role['add_edit_users']).to be(false)
      expect(role['make_super_admin']).to be(false)
      expect(role['access_scanpack']).to be(true)
      expect(role['access_orders']).to be(false)
      expect(role['access_products']).to be(false)
      expect(role['access_settings']).to be(false)
      expect(role['edit_general_prefs']).to be(false)
      expect(role['edit_scanning_prefs']).to be(false)
      expect(role['add_edit_stores']).to be(false)
      expect(role['create_backups']).to be(false)
      expect(role['restore_backups']).to be(false)
    end

    it "Should update the user role to 'Manager'" do
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_users, true)
      @access_restriction.update_attribute(:num_users, 1)
      post :createUpdateUser, { :username => 'test_user', :password => '12345678', :conf_password => '12345678', :role => {} }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['user']['confirmation_code']).to_not be_nil

      user = User.find_by_username('test_user')
      role_manager = {:access_orders=>true, :access_products=>true, :access_scanpack=>true, :access_settings=>false, :add_edit_order_items=>true, :add_edit_products=>true, :add_edit_stores=>false, :add_edit_users=>false, :change_order_status=>true, :create_backups=>true, :create_edit_notes=>true, :create_packing_ex=>true, :custom=>false, :delete_products=>false, :display=>true, :edit_general_prefs=>false, :edit_packing_ex=>false, :edit_scanning_prefs=>false, :import_orders=>true, :import_products=>false, :make_super_admin=>false, :name=>"Manager", :restore_backups=>false, :view_packing_ex=>true}
      post :createUpdateUser, { :id => user.id, :username => user.username, :active => true, :role => role_manager }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['user']['active']).to eq(true)
      expect(result['user']['role_id']).to_not be_nil
      expect(result['user']['role']).to_not  match_array([])
      role = result['user']['role']
      expect(role['add_edit_order_items']).to be(true)
      expect(role['import_orders']).to be(true)
      expect(role['change_order_status']).to be(true)
      expect(role['create_edit_notes']).to be(true)
      expect(role['view_packing_ex']).to be(true)
      expect(role['create_packing_ex']).to be(true)
      expect(role['edit_packing_ex']).to be(false)
      expect(role['delete_products']).to be(false)
      expect(role['import_products']).to be(false)
      expect(role['add_edit_products']).to be(true)
      expect(role['add_edit_users']).to be(false)
      expect(role['make_super_admin']).to be(false)
      expect(role['access_scanpack']).to be(true)
      expect(role['access_orders']).to be(true)
      expect(role['access_products']).to be(true)
      expect(role['access_settings']).to be(false)
      expect(role['edit_general_prefs']).to be(false)
      expect(role['edit_scanning_prefs']).to be(false)
      expect(role['add_edit_stores']).to be(false)
      expect(role['create_backups']).to be(true)
      expect(role['restore_backups']).to be(false)
    end

    it "Should update the user role to 'Admin'" do
      request.accept = "application/json"
      @user.role.update_attribute(:add_edit_users, true)
      @access_restriction.update_attribute(:num_users, 1)
      post :createUpdateUser, { :username => 'test_user', :password => '12345678', :conf_password => '12345678', :role => {} }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['status']).to eq(true)
      expect(result['user']['confirmation_code']).to_not be_nil

      user = User.find_by_username('test_user')
      role_admin = {:access_orders=>true, :access_products=>true, :access_scanpack=>true, :access_settings=>true, :add_edit_order_items=>true, :add_edit_products=>true, :add_edit_stores=>false, :add_edit_users=>true, :change_order_status=>true, :create_backups=>true, :create_edit_notes=>true, :create_packing_ex=>true, :custom=>false, :delete_products=>false, :display=>true, :edit_general_prefs=>true, :edit_packing_ex=>true, :edit_scanning_prefs=>true, :import_orders=>true, :import_products=>true, :make_super_admin=>false, :name=>"Admin", :restore_backups=>false, :view_packing_ex=>true}
      post :createUpdateUser, { :id => user.id, :username => user.username, :active => true, :role => role_admin }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['user']['active']).to eq(true)
      expect(result['user']['role_id']).to_not be_nil
      expect(result['user']['role']).to_not  match_array([])
      role = result['user']['role']
      expect(role['add_edit_order_items']).to be(true)
      expect(role['import_orders']).to be(true)
      expect(role['change_order_status']).to be(true)
      expect(role['create_edit_notes']).to be(true)
      expect(role['view_packing_ex']).to be(true)
      expect(role['create_packing_ex']).to be(true)
      expect(role['edit_packing_ex']).to be(true)
      expect(role['delete_products']).to be(false)
      expect(role['import_products']).to be(true)
      expect(role['add_edit_products']).to be(true)
      expect(role['add_edit_users']).to be(true)
      expect(role['make_super_admin']).to be(false)
      expect(role['access_scanpack']).to be(true)
      expect(role['access_orders']).to be(true)
      expect(role['access_products']).to be(true)
      expect(role['access_settings']).to be(true)
      expect(role['edit_general_prefs']).to be(true)
      expect(role['edit_scanning_prefs']).to be(true)
      expect(role['add_edit_stores']).to be(false)
      expect(role['create_backups']).to be(true)
      expect(role['restore_backups']).to be(false)
    end

    it "should call all user" do
      request.accept = "application/json"
      get :index
      expect(response.status).to eq(200)
    end

    it "should print confirmation code" do 
      request.accept = "application/pdf"
      get :print_confirmation_code, {id: @user.id}
      expect(response.status).to eq(200)
    end

    it "should create role" do 
      request.accept = "application/json"
      user_role = {"access_orders"=>true, "access_products"=>true, "access_scanpack"=>true, "access_settings"=>false, "add_edit_order_items"=>true, "add_edit_products"=>true, "add_edit_stores"=>false, "add_edit_users"=>false, "change_order_status"=>true, "create_backups"=>true, "create_edit_notes"=>true, "create_packing_ex"=>true, "custom"=>false, "delete_products"=>false, "display"=>true, "edit_general_prefs"=>false, "edit_packing_ex"=>false, "edit_scanning_prefs"=>false, "import_orders"=>true, "import_products"=>false, "make_super_admin"=>false, "restore_backups"=>false, "view_packing_ex"=>true, "new_name"=>"test"}
      get :create_role, {"id"=>@user.id, "username"=>@user.username, "active"=>true, "name"=>"TestUser", "inventory_warehouse_id"=>InventoryWarehouse.last.id, "role_id"=>Role.last.id, "view_dashboard"=>false, "is_deleted"=>false, "role"=> user_role, "current_user"=>{"active"=>true, "id"=>@user.id, "inventory_warehouse_id"=>InventoryWarehouse.last.id, "role_id"=>@user.role.id}, "user"=>{"username"=>@user.username}}
      expect(response.status).to eq(200)
    end

    it "should delete role" do
      request.accept = "application/json"
      @user.role.update_attribute(:name, "Scan & Pack User")
      user_role = {"id" => @user.role.id,"access_orders"=>true, "access_products"=>true, "access_scanpack"=>true, "access_settings"=>false, "add_edit_order_items"=>true, "add_edit_products"=>true, "add_edit_stores"=>false, "add_edit_users"=>false, "change_order_status"=>true, "create_backups"=>true, "create_edit_notes"=>true, "create_packing_ex"=>true, "custom"=>false, "delete_products"=>false, "display"=>true, "edit_general_prefs"=>false, "edit_packing_ex"=>false, "edit_scanning_prefs"=>false, "import_orders"=>true, "import_products"=>false, "make_super_admin"=>false, "restore_backups"=>false, "view_packing_ex"=>true, "new_name"=>"test"}
      get :delete_role, {"active"=>true, "current_user"=>{"active"=>true, "id"=>@user.id, "inventory_warehouse_id"=>InventoryWarehouse.last.id, "is_deleted"=>false, "name"=>@user.name, "role_id"=>@user.role.id, "username"=>@user.username, "view_dashboard"=>false}, "id"=>@user.id, "inventory_warehouse_id"=>InventoryWarehouse.last.id, "is_deleted"=>false, "name"=>"TestUser", "role"=> user_role, "role_id"=>@user.role.id, "username"=>@user.username, "view_dashboard"=>false, "user"=>{"username"=>@user.username}}
      expect(response.status).to eq(200)
    end

    it "should update status" do 
      request.accept = "application/json"
      post :change_user_status, {"_json" => [{"id"=>@user.id, "index"=>8, "active"=>true}]}
      expect(response.status).to eq(200)
    end

    it "should duplicate user" do 
      request.accept = "application/json"
      post :duplicate_user, {"_json" => [{"id"=>@user.id, "index"=>8, "active"=>true}]}
      expect(response.status).to eq(200)
    end

    it "should delete user" do
      request.accept = "application/json"
      post :delete_user, {"_json" => [{"id"=>@user.id, "index"=>8, "active"=>true}]}
      expect(response.status).to eq(200) 
    end

    it "should show" do
      request.accept = "application/json"
      get :show, {"id" => @user.id}
      expect(response.status).to eq(200) 
    end

    # it "should create tenant" do
    #   request.accept = "application/json"
    #   get :create_tenant, {"name" => "" }
    #   expect(response.status).to eq(200) 
    # end

  end
end
