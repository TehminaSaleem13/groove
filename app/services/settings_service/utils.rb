module SettingsService
  module Utils
    def validate_params
      return if params[:start].present? || params[:end].present?
      result['status'] = false
      result['messages'].push('We need a start and an end time')
    end

    def do_if_status_false
      return if result['status']
      result['data'] = CSV.generate do |csv|
        csv << result['messages']
      end
      result['filename'] = 'error.csv'
    end
  end
end
