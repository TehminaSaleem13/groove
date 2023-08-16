# frozen_string_literal: true

namespace :doo do
  desc 'Check access restriction is scheduled'
  task schedule_check_for_access_restriction: :environment do
    if $redis.get('send_email').blank?
      $redis.set('send_email', true)
      $redis.expire('send_email', 500)
      Tenant.where(is_cf: true).each do |tenant|
        Apartment::Tenant.switch! tenant.name
        access_restriction = AccessRestriction.order('created_at').last
        if (Date.today - Date.parse(access_restriction.created_at.strftime('%F'))).to_i > 31
          unless tenant.test_tenant_toggle
            StripeInvoiceEmail.remainder_for_access_restriction(tenant).deliver
            if access_restriction.present?
              AccessRestriction.create(num_users: access_restriction.num_users, num_shipments: access_restriction.num_shipments, num_import_sources: access_restriction.num_import_sources, allow_bc_inv_push: access_restriction.allow_bc_inv_push, allow_mg_rest_inv_push: access_restriction.allow_mg_rest_inv_push, allow_shopify_inv_push: access_restriction.allow_shopify_inv_push, allow_teapplix_inv_push: access_restriction.allow_teapplix_inv_push, allow_magento_soap_tracking_no_push: access_restriction.allow_magento_soap_tracking_no_push).save
            end
          end
        end
      rescue Exception => e
        puts e.message
        break
      end
      exit(1)
    end
  end
end
