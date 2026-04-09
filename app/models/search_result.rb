class SearchResult < ApplicationRecord
  belongs_to :user

  validates :case_number, presence: true, uniqueness: { scope: :user_id }
end
