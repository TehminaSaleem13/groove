class CreateTenant

	def self.create_tenant(subscription)
  	Apartment::Tenant.create(subscription.user_name)
    tenant = Tenant.create(name: subscription.user_name)
    subscription.tenant = tenant
    Apartment::Tenant.switch(subscription.user_name)
    SeedTenant.new.seed
    TransactionEmail.send_email(subscription).deliver
	end

end