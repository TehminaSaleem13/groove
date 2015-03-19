class ShipstationRestCredential < ActiveRecord::Base
  attr_accessible :api_key, :api_secret, :store_id
  validates_presence_of :api_key, :api_secret

  belongs_to :store

  def verify_tags
    context = Groovepacker::Store::Context.new(
      Groovepacker::Store::Handlers::ShipstationRestHandler.new(store))
    context.verify_tags([gp_ready_tag_name, gp_imported_tag_name])
  end

  def gp_ready_tag_name
    "GP Ready"
  end

  def gp_imported_tag_name
    "GP Imported"
  end

end

