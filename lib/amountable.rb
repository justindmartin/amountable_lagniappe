# Copyright 2015-2016, Instacart

module Amountable
  extend ActiveSupport::Autoload
  autoload :Operations
  autoload :Amount
  autoload :NilAmount
  autoload :VERSION
  autoload :TableMethods

  class InvalidAmountName < StandardError; end
  class MissingColumn < StandardError; end

  def self.included(base)
    base.extend Amountable::ActAsMethod
  end

  module InstanceMethods

    def all_amounts
      return self.amounts
      #@all_amounts ||= amounts.to_set
    end

    def find_amount(name)
      #puts "Name: #{name}"
      return self.amounts.find_by_name(name.to_sym)
      #(@amounts_by_name ||= {})[name.to_sym] ||= amounts.to_set.find { |am| am.name == name.to_s }
    end

    def find_amounts(names)
      # return self.amounts.where(:)
      amounts.to_set.select { |am| names.include?(am.name.to_sym) }
    end

    def validate_amount_names
      amounts.each do |amount|
        errors.add(:amounts, "#{amount.name} is not an allowed amount name.") unless self.class.allowed_amount_name?(amount.name)
      end
    end
  end

  module ActAsMethod

    def act_as_amountable(options = {})
      self.extend Amountable::ClassMethod
      class_attribute :tax_subtotal_amount_names
      class_attribute :tax_percentage_names
      class_attribute :tax_amount_amount_names

      class_attribute :amount_names
      class_attribute :amount_sets
      class_attribute :amounts_column_name
      
      self.tax_subtotal_amount_names = Array.new
      self.tax_percentage_names = Array.new
      self.tax_amount_amount_names = Array.new

      self.amount_sets = Hash.new { |h, k| h[k] = Set.new }
      self.amount_names = Array.new
      self.amounts_column_name = 'amounts'
      
      has_many :amounts, class_name: 'Amountable::Amount', as: :amountable, dependent: :destroy, autosave: false
      include Amountable::TableMethods

      validate :validate_amount_names
      include Amountable::InstanceMethods
    end

  end

  module ClassMethod
    def amount_set(set_name, component)
      self.amount_sets[set_name.to_sym] << component.to_sym

      define_method set_name do
        get_set(set_name)
      end
    end

    def amount(name, options = {})
      self.amount_names.push(name.to_sym)
      #(self.amount_names ||= Set.new) << name

      # define_method name do
      #TODO: Fix this tomorrow
        if self.tax_amount_amount_names.include?(name)
          self.tax_subtotal_amount_names.each_with_index do |tax_subtotal_amount_name, index|
            #calculate subtotal
            subtotal = self.send(tax_subtotal_amount_name)

            #get tax percentage
            tax_percentage = self.send(self.send(:tax_percentage_names).send(:[], index))

            #calculate tax
            tax = subtotal * tax_percentage.to_f

            #get tax amount name and set tax amount
            tax_amount_name = self.send(:tax_amount_amount_names).send(:[], index)

            self.amounts.find_by_name(tax_amount_name.to_sym).update_attributes(:value => tax)

            #return self.amounts.find_by_name(tax_amount_name.to_s)
          end
        end
        #(find_amount(name) || Amountable::NilAmount.new).value
      # end

      define_method name do
        if self.respond_to?("amounts") && !self.id.nil?
          amount = self.amounts.find_or_initialize_by(
            :amountable_id => self.id,
            :amountable_type => self.class.name,
            :name => name.to_s
          )

          if amount.id.nil?
            amount.value = Money.new(0)
          end

          amount.save()

          return Money.new(amount.value)
        else
          return Money.new(0)
        end
      end

      define_method "#{name}=" do |value|
        if self.respond_to?("amounts") && !self.id.nil?
          amount = self.amounts.find_or_initialize_by(
            :amountable_id => self.id,
            :amountable_type => self.class.name,
            :name => name.to_s
          )
          amount.value = value.to_money
          amount.save()

          return Money.new(amount.value)
          #set_amount(name, value)
        end
      end

      Array(options[:summable] || options[:summables] || options[:set] || options[:sets] || options[:amount_set] || options[:amount_sets]).each do |set|
        amount_set(set, name)
      end
    end

    def tax(options = {})
      self.tax_subtotal_amount_names.push(options[:from])
      self.tax_percentage_names.push(options[:with])
      self.tax_amount_amount_names.push(options[:to])
    end

    def allowed_amount_name?(name)
      puts "Allowed: #{self.amount_names.include?(name.to_sym)}"
      self.amount_names.include?(name.to_sym)
    end

    def pg_json_field_access(name, field = :cents)
      name = name.to_sym
      group = if name.in?(self.amount_names)
        'amounts'
      elsif name.in?(self.amount_sets.keys)
        'sets'
      end
      "#{self.amounts_column_name}::json#>'{#{group},#{name},#{field}}'"
    end

  end
end

ActiveSupport.on_load(:active_record) do
  include Amountable
end
