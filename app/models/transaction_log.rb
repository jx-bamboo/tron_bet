class TransactionLog < ApplicationRecord
  belongs_to :member
  belongs_to :block_record
end
