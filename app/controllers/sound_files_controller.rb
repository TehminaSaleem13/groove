class SoundFilesController < ApplicationController
  before_action :groovepacker_authorize!
    def create_sounds
      sound_type = params[:sound_type]
      file_paths = params[:file_paths]
      content_type = params[:content_type] || 'audio/mpeg' 
      privacy = params[:privacy] || :public_read  
      user_name = current_user.name || current_user.username
      tenant = Apartment::Tenant.current
      begin
        public_urls = GroovS3.create_sound_from_system(tenant, file_paths, user_name, sound_type, content_type, privacy)
        render json: { status: 'success', urls: public_urls }, status: :ok
      rescue => e
        render json: { status: 'error', message: e.message }, status: :unprocessable_entity
      end
    end
    
    def get_sounds_files
      user_name = current_user.name || current_user.username
      begin
        sounds = GroovS3.get_sounds_export(user_name)
        render json: { status: 'success', sounds: sounds }, status: :ok
      rescue => e
        render json: { status: 'error', message: e.message }, status: :unprocessable_entity
      end
    end

    def remove_sounds
        result = { status: true, failed_files: [] }
        json_params = JSON.parse(request.body.read)

        sound_type = json_params["sound_type"]
        file_names = json_params["file_names"]
        tenant = Apartment::Tenant.current
        user_name = current_user.name || current_user.username   
        file_names = Array(file_names)
    
        file_names.each do |file_name|
          file_deleted = GroovS3.delete_object_sound(tenant, sound_type, file_name, user_name)
    
          if !file_deleted
            result[:failed_files] << file_name
          end
        end
    
        if result[:failed_files].empty?
          render json: { status: true, message: 'Files deleted successfully' }
        else
          render json: { status: false, failed_files: result[:failed_files] }
        end
    end
end
  