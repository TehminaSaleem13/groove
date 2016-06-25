class ShipstationRestCredentialsController < ApplicationController
  before_filter :groovepacker_authorize!

  def fix_import_dates
  	@result = {"status" => true, "messages" => ""}
  	@credential = ShipstationRestCredential.find_by_store_id(params["store_id"])
  	@credential.last_imported_at = 24.hours.ago
  	@credential.quick_import_last_modified = 24.hours.ago
  	if @credential.save
      @result["messages"] = "Successfully Updated"
    else
      @result["messages"] = "Something went wrong"
      @result["status"] = false
    end
  	render json: @result
  end

end
