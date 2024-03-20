# frozen_string_literal: true

class GroovepackerWebhooksController < ApplicationController
  before_action :groovepacker_authorize!
  before_action :set_webhook, only: :update

  def create
    @groovepacker_webhook = GroovepackerWebhook.new(webhook_params)
    if @groovepacker_webhook.save
      render json: { data: @groovepacker_webhook, message: 'Successfully Created Webhook' }, status: :created
    else
      render json: { errors: @groovepacker_webhook.errors }, status: :unprocessable_entity
    end
  end

  def update
    if @groovepacker_webhook.update(webhook_params)
      render json: { data: @groovepacker_webhook, message: 'Successfully Updated Webhook' }, status: :created
    else
      render json: @groovepacker_webhook.errors, status: :unprocessable_entity
    end
  end

  def delete_webhooks
    @groovepacker_webhooks = GroovepackerWebhook.where(id: params[:webhook_ids])
    @groovepacker_webhooks.destroy_all
    render json: { status: true, message: 'Successfully Deleted Webhooks ' }, status: :ok
  end

  private

  def set_webhook
    @groovepacker_webhook = GroovepackerWebhook.find(params[:id])
  end

  def webhook_params
    params.require(:webhook).permit(:secret_key, :url, :event)
  end
end
