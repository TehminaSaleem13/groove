# frozen_string_literal: true

module AhoyEvent
  def track_user(tenant, params, name, title)
    ahoy = Ahoy::Event.new
    ahoy.name = name
    ahoy.properties = {
      title: title,
      tenant: tenant,
      store_id: (begin
                   (params[:store_id] || params[:store].id)
                 rescue StandardError
                   nil
                 end),
      user_id: (begin
                  (params[:user_id] || params[:user].id)
                rescue StandardError
                  nil
                end)
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
