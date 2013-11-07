require "pundit/version"
require "pundit/policy_finder"
require "active_support/concern"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/object/blank"

module Pundit
  class NotAuthorizedError < StandardError; end
  class NotDefinedError < StandardError; end

  extend ActiveSupport::Concern

  class << self
    def policy_scope(user, scope)
      policy = PolicyFinder.new(scope).scope
      policy.new(user, scope).resolve if policy
    end

    def policy_scope!(user, scope)
      PolicyFinder.new(scope).scope!.new(user, scope).resolve
    end

    def policy(user, record)
      scope = PolicyFinder.new(record).policy
      scope.new(user, record) if scope
    end

    def policy!(user, record)
      PolicyFinder.new(record).policy!.new(user, record)
    end
  end

  included do
    if respond_to?(:helper_method)
      helper_method :policy_scope
      helper_method :policy
      helper_method :pundit_user
    end
    if respond_to?(:hide_action)
      hide_action :authorize
      hide_action :verify_authorized
      hide_action :verify_policy_scoped
      hide_action :pundit_user
      hide_action :pundit_error_message
    end
  end

  def verify_authorized
    raise NotAuthorizedError unless @_policy_authorized
  end

  def verify_policy_scoped
    raise NotAuthorizedError unless @_policy_scoped
  end

  def authorize(record, query=nil)
    @_policy_authorized = true
    query ||= params[:action].to_s + "?"
    unless policy(record).public_send(query)
      raise NotAuthorizedError, pundit_error_message(record, query)
    end
    true
  end

  def policy_scope(scope)
    @_policy_scoped = true
    @policy_scope or Pundit.policy_scope!(pundit_user, scope)
  end
  attr_writer :policy_scope

  def policy(record)
    @policy or Pundit.policy!(pundit_user, record)
  end
  attr_writer :policy

  def pundit_user
    current_user
  end

  def pundit_error_message(record, query)
    query = query.to_s.gsub(/\?$/, '')
    message_query = "#{query}_failed_message"
    message = policy(record).respond_to?(message_query) && policy(record).public_send(message_query)
    message ||= "You are not allowed to perform this action."
  end
end
