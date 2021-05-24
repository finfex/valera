# frozen_string_literal: true

# Bot strategy for specific market
# Rename to Strategy
#
# rubocop:disable Metrics/ClassLength
#
class Strategy
  include AutoLogger
  extend Finders

  UPDATE_PERIOD_SEC = Rails.env.production? ? 0.3 : 1

  attr_reader :account, :market, :name, :state, :comment, :logger, :updater, :upstream_markets

  delegate :description, :settings_class, :state_class, to: :class
  delegate :is_active, to: :settings
  delegate :active_orders, to: :account

  def self.description
    raise 'undefined strategy'
  end

  def self.settings_class
    return [name, 'Settings'].join('::').constantize if constants.include? :Settings

    StrategySettings
  end

  def self.state_class
    return [name, 'State'].join('::').constantize if constants.include? :State

    StrategyState
  end

  # @param name [String] key of bot from Rails credentials
  # @param market [Market]
  def initialize(name:, market:, account:, default_settings: {}, comment: nil)
    @name = name
    @market = market
    @default_settings = default_settings
    @account = account
    @state = state_class.build id: id
    @comment = comment
    @logger = ActiveSupport::TaggedLogging.new(_build_auto_logger).tagged([self.class, id].join(' '))
    @updater = OrdersUpdater.new(market: market, account: account, name: name)
    # TODO: customize used upstreams
    @upstreams = Upstream.all
    @upstream_markets = market.upstream_markets
  end

  def class_and_name
    "[#{self.class.name}]#{name}"
  end

  def reload
    settings.reload
    state.reload
    account.reload
    upstream_markets.each(&:reload)
    self
  end

  def title
    "[#{self.class.name}]#{id}"
  end
  alias to_s title

  def stop!(reason = 'No reason')
    state.stop! reason
    logger.info "Stop with #{reason}"
    updater.cancel!
    state.update_attributes! created_orders: []
  end

  def start!
    logger.info 'Start'
    state.start!
  end

  def perform
    reload
    bump! if state.updated_at.nil? || Time.zone.now - state.updated_at > settings.base_latency
  end

  # Change state
  # @param changes [Hash]
  def bump!(changes = {})
    logger.debug "Bump with #{changes}"

    if settings.enabled && state.is_active?
      state.update_attributes! created_orders: updater.update!(build_orders)
    elsif state.created_orders.present? || account.active_orders.present?
      logger.info 'Does not update bot orders because bot is disabled or inactive. Cancel all orders'
      updater.cancel!
      state.update_attributes! created_orders: []
    else
      logger.debug 'Strategy is disabled. Do nothing'
      state.touch!
    end

    StrategyChannel.update self
  rescue Peatio::Client::REST => e
    logger.error "#{self} #{e}"
  rescue StandardError => e
    report_exception e
    logger.error "#{self} #{e}"
  end

  def id
    [name, market.id].join('-')
  end
  alias to_param id

  def reset_settings!
    settings_class.new(id: id).update_attributes! @default_settings
    remove_instance_variable :@settings if instance_variable_defined? :@settings
  end

  def settings
    return @settings if instance_variable_defined? :@settings

    @settings = settings_class.build id: id
  end

  private

  def build_orders
    Set.new(
      Order::SIDES.map do |side|
        build_order(side, calculate_price(side), calculate_volume(side))
      end.compact
    )
  end

  def build_order(side, price, volume, level = 0)
    if price.nil?
      logger.warn 'Skip order building for side because price is undefined'
      nil
    else
      logger.debug "build_order(#{side}, #{price}, #{volume})"
      Order.build(side: side, price: price, volume: volume, level: level)
    end
  end

  def calculate_price(_side)
    raise 'not implemented'
  end

  def calculate_volume(_side)
    raise 'not implemented'
  end
end
# rubocop:enable Metrics/ClassLength
