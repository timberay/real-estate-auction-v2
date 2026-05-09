# frozen_string_literal: true

# Renders a read-only citation block (source document, page number, and quote)
# next to AI-generated reasoning so reviewers can verify the original source
# without re-reading the PDF in full.
#
# All fields are optional — render nothing when all are blank.
class EvidenceLinkComponent < ViewComponent::Base
  def initialize(source_doc: nil, page_number: nil, quote: nil)
    @source_doc = source_doc.presence
    @page_number = page_number
    @quote = quote.presence
  end

  def render?
    @source_doc.present? || @page_number.present? || @quote.present?
  end

  private

  attr_reader :source_doc, :page_number, :quote

  def header?
    source_doc.present? || page_number.present?
  end

  def page_label
    "p.#{page_number}"
  end
end
