# Remove all currencies
Money::Currency.all.each do |cur|
  Money::Currency.unregister cur.id.to_s
end

# Add our currencies
Psych.load( File.read './config/currencies.yml' ).each { |key, cur| Money::Currency.register cur.symbolize_keys }

# Create currency constants
Money::Currency.all.each do |cur|
  Object.const_set cur.iso_code, cur
end

class Money::Currency
  def self.all_crypto
    @all_crypto ||= all.select(&:is_crypto?)
  end

  def zero_money
    Money.from_amount(0, self)
  end

  def initialize_data!
    super
    data = self.class.table[@id]
    @is_crypto = data[:is_crypto]
  end

  def is_crypto?
    !!@is_crypto
  end

  def precision
    8
  end
end
