# Copyright 2015-2016, Instacart

if jsonb_available?
  class Subscription < ActiveRecord::Base

    include Amountable
    act_as_amountable storage: :jsonb
    amount :sub_total, sets: [:total]
    amount :taxes, sets: [:total]

  end
end