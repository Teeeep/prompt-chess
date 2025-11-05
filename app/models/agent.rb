class Agent < ApplicationRecord
  validates :name, presence: true, length: { minimum: 1, maximum: 100 }
  validates :prompt_text, presence: true, length: { minimum: 10, maximum: 10_000 }
  validates :role, length: { maximum: 50 }, allow_blank: true

  validate :configuration_not_nil

  private

  def configuration_not_nil
    errors.add(:configuration, "can't be blank") if configuration.nil?
  end
end
