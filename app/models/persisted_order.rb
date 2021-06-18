# frozen_string_literal: true

# Stored in peatio order
#
# Posible values
# {"id"=>484418,
# "uuid"=>"45df48c1-8971-488a-a0d7-4f81e6786a94",
# "side"=>"sell",
# "ord_type"=>"limit",
# "price"=>"61816.377",
# "avg_price"=>"0.0",
# "state"=>"wait",
# "market"=>"btcusdt",
# "market_type"=>"spot",
# "created_at"=>"2021-05-10T08:51:51Z",
# "updated_at"=>"2021-05-10T08:51:51Z",
# "origin_volume"=>"0.001",
# "remaining_volume"=>"0.001",
# "executed_volume"=>"0.0",
# "maker_fee"=>"0.0",
# "taker_fee"=>"0.0",
# "trades_count"=>0}
#
class PersistedOrder
  PRECISION = Order::PRECISION

  include Virtus.model
  include SideInquirer

  attribute :id, Integer
  attribute :raw, Hash

  attribute :side, String # One of Order::SIDES
  attribute :origin_volume, BigDecimal
  attribute :remaining_volume, BigDecimal
  attribute :price, BigDecimal
  attribute :market_id, String # Our market_id

  def initialize(attrs)
    super(attrs).freeze
  end

  def <=>(other)
    return nil unless side == other.side

    -price <=> -other.price
  end

  def side?(asked_side)
    asked_side = asked_side.to_s

    raise "Unknown side #{asked_side}" unless Order::SIDES.map(&:to_s).include? asked_side

    asked_side == side
  end

  def inspect
    to_s
  end

  def market
    @market ||= Market.find market_id
  end

  def to_s
    id.to_s + '#' + # rubocop:disable Style/StringConcatenation
      side.to_s + ':' +
      format("%0.#{PRECISION}f", origin_volume) + 'x' +
      format("%0.#{PRECISION}f", price)
  end
end
