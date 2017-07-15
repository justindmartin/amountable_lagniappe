# Copyright 2015-2016, Instacart

module Amountable
  module TableMethods
    extend ActiveSupport::Autoload

    def set_amount(name, value)
      amount = self.amounts.find_or_create_by(
        :amountable_id => self.id,
        :amountable_type => self.class.name,
        :name => name.to_s
      )

      amount.update_attributes(:value => value.to_money)

      #amount = find_amount(name) || amounts.build(name: name)
      #amount.value = value.to_money

      # if value.zero?
      #   amounts.delete(amount)
      #   all_amounts.delete(amount)
      #   @amounts_by_name.delete(name)
      #   amount.destroy if amount.persisted?
      # else
      #   all_amounts << amount if amount.new_record?
      #   (@amounts_by_name ||= {})[name.to_sym] = amount
      # end

      return amount
    end

    # def save(args = {})
    #   ActiveRecord::Base.transaction do
    #     save_amounts if super(args)
    #   end
    # end

    # def save!(args = {})
    #   ActiveRecord::Base.transaction do
    #     save_amounts! if super(args)
    #   end
    # end

    def save(args = {})
      ActiveRecord::Base.transaction do
        if super
          self.tax_subtotal_amount_names.each_with_index do |tax_subtotal_amount_name, index|
            #calculate subtotal
            subtotal = self.send(tax_subtotal_amount_name)

            #get tax percentage
            tax_percentage = self.send(self.send(:tax_percentage_names).send(:[], index))

            #calculate tax
            tax = subtotal * tax_percentage.to_f

            #get tax amount name and set tax amount
            tax_amount_name = self.send(:tax_amount_amount_names).send(:[], index)

            puts "Setting #{tax_amount_name} to #{tax}"
            return self.amounts.find_or_initialize_by(:name => tax_amount_name.to_sym).update_attributes(:value => tax)
          end
        end
      end

      # amounts_to_insert = []
      # amounts.each do |amount|
      #   if amount.new_record?
      #     amount.amountable_id = self.id
      #     amounts_to_insert << amount
      #   else
      #     amount.update(amount.attributes)
      #     bang ? amount.save! : amount.save
      #   end
      # end
      # Amount.import(amounts_to_insert, timestamps: true, validate: false)
      # amounts_to_insert.each do |amount|
      #   amount.instance_variable_set(:@new_record, false)
      # end
      true
    end

    # def save_amounts!; save_amounts(bang: true); end

    def get_set(name)
      find_amounts(self.amount_sets[name.to_sym]).sum(Money.zero, &:value)
    end

  end
end
