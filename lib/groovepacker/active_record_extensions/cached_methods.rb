# frozen_string_literal: true

# ========================================
#                  USAGE
# ========================================
# // Ruby.
# Class OrderItem
#   ...
#   # this code generates some instance methods
#   # cached_product and cached_order_item_kit_products
#   # which when called the first time, will cache the ActiveRecord Object,
#   # and after every call will get the object back from the cache only.
#   # You can also cache the method results too.
#   # Also it creates cache check instance methods
#   # as in this case product_is_cached? And order_item_kit_products_is_cached?
# => cached_methods :product, :order_item_kit_products
#   # As the name suggests, this method will clear all the cache related
#   # to the class.
# => after_save :delete_cache
#   ...
# end
module CachedMethods
  extend ActiveSupport::Concern

  module ClassMethods
    def cached_methods(*methods)
      methods.each do |association|
        define_method("cached_#{association}") do |key = nil, cached = nil|
          key = "#{association}_for_#{self.class.to_s.underscore}_#{id}_for_tenant_#{tenant_value}"
          cached = begin
            instance = "@cached_#{association}"
            (
              instance_variable_defined?(instance) &&
              instance_variable_get(instance)
            ) || instance_variable_set(instance, read_multi(key))
                   rescue StandardError
                     nil
          end
          if cached
            begin
              if cached.class.in?([ActiveRecord::Relation, Array])
                cached = cached.to_a
                cached.each { |c| c.send(:clear_association_cache) }
              else
                cached.send(:clear_association_cache)
              end
            rescue StandardError
              nil
            end
            return cached
          end
          load_assoc = send(association)
          load_assoc = load_assoc.to_a if load_assoc.class == ActiveRecord::Relation
          begin
            Rails.cache.write(key, load_assoc, expires_in: 5.minutes)
          rescue StandardError
            nil
          end
          update_cache_keys(key)
          load_assoc
        end

        define_method("#{association}_is_cached?") do
          key = "#{association}_for_#{self.class.to_s.underscore}_#{id}_for_tenant_#{tenant_value}"
          instance = "@cached_#{association}"
          (
            instance_variable_defined?(instance) &&
            instance_variable_get(instance)
          ) || Rails.cache.read(key).present?
        end
      end
    end
  end

  define_method('update_cache_keys') do |key|
    keys = Rails.cache.read(multi_key) || []
    keys << key
    keys = keys.class == String ? Marshal.load(keys) : keys
    begin
      Rails.cache.write(multi_key, keys.uniq)
    rescue StandardError
      nil
    end
  end

  def delete_cache
    cached = Rails.cache.read(multi_key)
    return unless cached

    cached = cached.class == String ? Marshal.load(cached) : cached
    cached.each { |key| Rails.cache.delete(key) }
    Rails.cache.delete(multi_key)
  end

  def multi_key
    @multi_key ||= "#{self.class.to_s.underscore}_#{id}_cache_keys_for_tenant_#{tenant_value}"
  end

  def keys
    Rails.cache.read(multi_key)
  end

  def keys?
    keys.present?
  end

  def tenant_value
    @tenant_value ||= Apartment::Tenant.current
  end

  def read_multi(key)
    @read_multi[key] || @read_multi.merge!(key => Rails.cache.read(key))[key]
  rescue StandardError
    (@read_multi = { key => Rails.cache.read(key) })[key]
  end
end
