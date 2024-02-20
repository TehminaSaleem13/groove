# frozen_string_literal: true

class AddSignatureToDelayedJob < ActiveRecord::Migration[5.1]
  def change
    add_column :delayed_jobs, :signature, :string
    add_column :delayed_jobs, :args, :text
  end
end