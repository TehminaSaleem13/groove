class AccessRestriction < ActiveRecord::Base
  attr_accessible :tenant_id, :num_users, :num_shipments, :num_import_sources, :total_scanned_shipments
  has_one :tenant
end
