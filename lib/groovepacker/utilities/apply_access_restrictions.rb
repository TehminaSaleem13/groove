class ApplyAccessRestrictions
  def self.apply_access_restrictions(invoice_id)
    Apartment::Tenant.switch()
    invoice = Invoice.find(invoice_id)
    unless Subscription.where(stripe_customer_id: invoice.customer_id).empty?
      subscription = Subscription.where(stripe_customer_id: invoice.customer_id).first
      unless subscription.tenant.nil? || subscription.tenant.name.nil?
        tenant = subscription.tenant.name
        Apartment::Tenant.switch(tenant)
        access_restriction = AccessRestriction.order("created_at").last unless AccessRestriction.order("created_at").last.nil?
        unless access_restriction.nil?
          AccessRestriction.create(num_users: access_restriction.num_users, num_shipments: access_restriction.num_shipments, num_import_sources: access_restriction.num_import_sources).save if access_restriction
        else
          if invoice.plan_id == "groove-solo"
            AccessRestriction.create(
              num_users: '1',
              num_shipments: '500',
              num_import_sources: '1',
              total_scanned_shipments: '0')
          elsif invoice.plan_id == 'groove-duo'
            AccessRestriction.create(
              num_users: '2',
              num_shipments: '2000',
              num_import_sources: '2',
              total_scanned_shipments: '0')
          elsif invoice.plan_id == 'groove-trio'
            AccessRestriction.create(
              num_users: '3',
              num_shipments: '6000',
              num_import_sources: '3',
              total_scanned_shipments: '0')
          elsif invoice.plan_id == 'groove-quintet'
            AccessRestriction.create(
              num_users: '5',
              num_shipments: '12000',
              num_import_sources: '5',
              total_scanned_shipments: '0')
          elsif invoice.plan_id == 'groove-symphony'
            AccessRestriction.create(
              num_users: '12',
              num_shipments: '50000',
              num_import_sources: '8',
              total_scanned_shipments: '0')
          elsif invoice.plan_id == "annual-groove-solo"
            AccessRestriction.create(
              num_users: '1',
              num_shipments: '500',
              num_import_sources: '1',
              total_scanned_shipments: '0')
          elsif invoice.plan_id == 'annual-groove-duo'
            AccessRestriction.create(
              num_users: '2',
              num_shipments: '2000',
              num_import_sources: '2',
              total_scanned_shipments: '0')
          elsif invoice.plan_id == 'annual-groove-trio'
            AccessRestriction.create(
              num_users: '3',
              num_shipments: '6000',
              num_import_sources: '3',
              total_scanned_shipments: '0')
          elsif invoice.plan_id == 'annual-groove-quintet'
            AccessRestriction.create(
              num_users: '5',
              num_shipments: '12000',
              num_import_sources: '5',
              total_scanned_shipments: '0')
          elsif invoice.plan_id == 'annual-groove-symphony'
            AccessRestriction.create(
              num_users: '12',
              num_shipments: '50000',
              num_import_sources: '8',
              total_scanned_shipments: '0')
          end
        end
      end
    end
  end
end
