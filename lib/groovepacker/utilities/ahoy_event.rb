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
    ahoy.time = Time.current
    ahoy.save!
  end

  def track_changes(params)
    ahoy = Ahoy::Event.new
    ahoy.name = params[:title]
    ahoy.version_2 = true
    ahoy.properties = {
      title: params[:title],
      tenant: params[:tenant],
      username: params[:username],
      object_id: params[:object_id],
      changes: params[:changes]
    }
    ahoy.time = Time.current
    ahoy.save!
  end
end
