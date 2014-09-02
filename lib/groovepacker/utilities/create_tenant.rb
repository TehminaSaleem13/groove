    class CreateTenant
    	def self.create_tenant(subscription)
          	Apartment::Tenant.create(subscription.tenant_name)
            tenant = Tenant.create(name: subscription.tenant_name)
            subscription.tenant = tenant
            Apartment::Tenant.switch(subscription.tenant_name)
            SeedTenant.new.seed(subscription.user_name, subscription.email, subscription.password)
            CreateTenant.apply_restrictions(subscription.subscription_plan_id)
            TransactionEmail.send_email(subscription).deliver
    	end
        
    	def self.apply_restrictions(plan)
    		if plan == "groove1"
                AccessRestriction.create( 
                    num_users: '1', 
                    num_shipments: '500',
                    num_import_sources: '1',
                    total_scanned_shipments: '0')
            elsif plan == 'groove2'
                AccessRestriction.create(
                    num_users: '2',
                    num_shipments: '2000',
                    num_import_sources: '2',
                    total_scanned_shipments: '0')
            elsif plan == 'groove3'
                AccessRestriction.create(
                    num_users: '3',
                    num_shipments: '6000',
                    num_import_sources: '3',
                    total_scanned_shipments: '0')
            elsif plan == 'groove4'
                AccessRestriction.create(
                    num_users: '5',
                    num_shipments: '12000',
                    num_import_sources: '5',
                    total_scanned_shipments: '0')
            elsif plan == 'groove5'
                AccessRestriction.create(
                    num_users: '12',
                    num_shipments: '50000',
                    num_import_sources: '8',
                    total_scanned_shipments: '0')
            end
    	end
    end
