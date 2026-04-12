class Property < ApplicationRecord
  has_many :auction_schedules, dependent: :destroy

  has_many :user_properties, dependent: :destroy
  has_many :users, through: :user_properties
  has_many :inspection_results, dependent: :destroy
  has_many :inspection_items, through: :inspection_results
  has_many :rights_analysis_reports, dependent: :destroy
  has_many :llm_analysis_logs, dependent: :destroy

  has_many_attached :documents

  validates :case_number, presence: true, uniqueness: true
  validate :documents_must_be_pdf

  def analyzed?
    inspection_results.exists?
  end

  def needs_manual_input?
    inspection_results.where(has_risk: nil).exists?
  end

  private

  def documents_must_be_pdf
    documents.each do |doc|
      unless doc.content_type == "application/pdf"
        errors.add(:documents, "PDF 파일만 업로드할 수 있습니다.")
      end
    end
  end
end
