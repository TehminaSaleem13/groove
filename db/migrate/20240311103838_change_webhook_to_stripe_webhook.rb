class ChangeWebhookToStripeWebhook < ActiveRecord::Migration[5.1]
  def change
    rename_table :webhooks, :stripe_webhooks
  end
end
