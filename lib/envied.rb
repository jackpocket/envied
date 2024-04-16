require 'envied/version'
require 'envied/env_proxy'
require 'envied/coercer'
require 'envied/coercer/envied_string'
require 'envied/variable'
require 'envied/configuration'

class ENVied
  class << self
    attr_reader :env, :config
    alias_method :required?, :env
  end

  def self.require(*args, **options)
    requested_groups = (args && !args.empty?) ? args : ENV['ENVIED_GROUPS']
    env!(requested_groups, **options)
    error_on_missing_variables!(**options)
    error_on_uncoercible_variables!(**options)
  end

  def self.env!(requested_groups, **options)
    @config = options.fetch(:config) { Configuration.load }
    @env = EnvProxy.new(@config, groups: required_groups(*requested_groups))
  end

  def self.error_on_missing_variables!(**options)
    names = env.missing_variables.map(&:name)
    if names.any?
      raise "The following environment variables should be set: #{names.join(', ')}."
    end
  end

  def self.error_on_uncoercible_variables!(**options)
    errors = env.uncoercible_variables.map do |v|
      format("%{name} with %{value} (%{type})", name: v.name, value: env.value_to_coerce(v).inspect, type: v.type)
    end
    if errors.any?
      raise "The following environment variables are not coercible: #{errors.join(", ")}."
    end
  end

  def self.required_groups(*groups)
    splitter = ->(group){ group.is_a?(String) ? group.split(/ *, */) : group }
    result = groups.compact.map(&splitter).flatten
    result.any? ? result.map(&:to_sym) : [:default]
  end

  def self.method_missing(method, *args, &block)
    respond_to_missing?(method) ? (env && env[method.to_s]) : super
  end

  def self.respond_to_missing?(method, include_private = false)
    (env && env.has_key?(method)) || super
  end
end
