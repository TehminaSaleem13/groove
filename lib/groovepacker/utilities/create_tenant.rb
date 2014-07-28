class CreateTenant

	def self.create_tenant(subscription)
  	Apartment::Tenant.create(subscription.tenant_name)
    tenant = Tenant.create(name: subscription.tenant_name)
    subscription.tenant = tenant
    Apartment::Tenant.switch(subscription.tenant_name)
    SeedTenant.new.seed
    TransactionEmail.send_email(subscription).deliver
	end

end