class SoundFilesController < ApplicationController
  
    def create_sounds
      sound_type = params[:sound_type]
      file_paths = params[:file_paths]
      content_type = params[:content_type] || 'audio/mpeg' 
      privacy = params[:privacy] || :public_read  
      tenant = Apartment::Tenant.current
      begin
        public_urls = GroovS3.create_sound_from_system(tenant, file_paths, sound_type, content_type, privacy)
        render json: { status: 'success', urls: public_urls }, status: :ok
      rescue => e
        render json: { status: 'error', message: e.message }, status: :unprocessable_entity
      end
    end
    
    def get_sounds_files
      begin
        sounds = GroovS3.get_sounds_export
        render json: { status: 'success', sounds: sounds }, status: :ok
      rescue => e
        render json: { status: 'error', message: e.message }, status: :unprocessable_entity
      end
    end

    def remove_sounds
        result = { status: true, failed_files: [] }
        file_names = params[:file_names]
        sound_type = params[:sound_type]
        tenant = Apartment::Tenant.current
    
        file_names = Array(file_names)
    
        file_names.each do |file_name|
          file_deleted = GroovS3.delete_object_sound(tenant, sound_type, file_name)
    
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
  