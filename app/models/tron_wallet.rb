class TronWallet < ApplicationRecord
  belongs_to :member, optional: true

  validates :address, :private_key, presence: true, uniqueness: true
end
