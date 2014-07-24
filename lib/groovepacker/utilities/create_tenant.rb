class CreateTenant

	def self.create_tenant(user_name)
  	Apartment::Tenant.create(user_name)
    Apartment::Tenant.switch(user_name)
    SeedTenant.new.seed
	end

end