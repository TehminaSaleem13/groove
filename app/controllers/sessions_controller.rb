class SessionsController < Devise::SessionsController

  def new
    super
  end

  def create
    # puts "create"
    puts "auth_options: " + auth_options.inspect
    self.resource = warden.authenticate!(auth_options)
    set_flash_message(:notice, :signed_in) if is_flashing_format?
    sign_in(resource_name, resource)
    # Doorkeeper::Application.new :name => 'Groovepacker', :redirect_uri => ''
    # puts "doorkeeper_token.application: " + doorkeeper_token.application.inspect if doorkeeper_token
    # puts "current_user----" + current_user.inspect
    # puts "self: " + self.inspect
    # response = HTTParty.post('http://localtest16.localpacker.com/auth/v1/login', headers: { "Content-Type" => "application/json", "Accept" => "application/json" }, body: {"username" => current_user.username, "password" => '12345678'})
    # puts "response: " + response.inspect
    # if !session[:return_to].blank?
    #   puts "resource: " + resource.inspect
    # end
    yield resource if block_given?
    respond_with resource, location: after_sign_in_path_for(resource)
    # self.resource = warden.authenticate!(auth_options)
    #   set_flash_message(:notice, :signed_in) if is_navigational_format?
    #   sign_in(resource_name, resource)
    #   if !session[:return_to].blank?
    #     redirect_to session[:return_to]
    #     session[:return_to] = nil
    #   else
    #     respond_with resource, :location => after_sign_in_path_for(resource)
    #   end
  end

end