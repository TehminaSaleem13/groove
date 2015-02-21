    class CreateTenant
    	def self.create_tenant(subscription)
          	Apartment::Tenant.create(subscription.tenant_name)
            tenant = Tenant.create(name: subscription.tenant_name)
            subscription.tenant = tenant
            Apartment::Tenant.switch(subscription.tenant_name)
            CreateTenant.apply_restrictions(subscription.subscription_plan_id)
            SeedTenant.new.seed(true,subscription.user_name, subscription.email, subscription.password)
            TransactionEmail.delay(run_at: 2.hours.from_now).send_email(subscription)
            TransactionEmail.welcome_email(subscription).deliver
    	end

    	def self.apply_restrictions(plan)
    		if plan == "groove-solo"
                AccessRestriction.create(
                    num_users: '1',
                    num_shipments: '500',
                    num_import_sources: '1',
                    total_scanned_shipments: '0')
            elsif plan == 'groove-duo'
                AccessRestriction.create(
                    num_users: '2',
                    num_shipments: '2000',
                    num_import_sources: '2',
                    total_scanned_shipments: '0')
            elsif plan == 'groove-trio'
                AccessRestriction.create(
                    num_users: '3',
                    num_shipments: '6000',
                    num_import_sources: '3',
                    total_scanned_shipments: '0')
            elsif plan == 'groove-quintet'
                AccessRestriction.create(
                    num_users: '5',
                    num_shipments: '12000',
                    num_import_sources: '5',
                    total_scanned_shipments: '0')
            elsif plan == 'groove-symphony'
                AccessRestriction.create(
                    num_users: '12',
                    num_shipments: '50000',
                    num_import_sources: '8',
                    total_scanned_shipments: '0')
            end
    	end
    end
