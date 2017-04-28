module AhoyEvent
  
  def track_user(tenant, params, name, title)
    ahoy = Ahoy::Event.new
    ahoy.name = name
    ahoy.properties = {
      title: title,
      tenant: tenant,
      store_id: ((params[:store_id] || params[:store].id) rescue nil),
      user_id: ((params[:user_id] || params[:user].id) rescue nil)
    }
    ahoy.time = Time.now
    ahoy.save!
  end

end
