require "test_helper"

# Cross-user authorization (IDOR) hardening test (PR-2 of pre-launch hardening plan).
#
# Asserts that a session user cannot reach property-scoped endpoints for a
# property they don't own — even when *another* user does own it. Every
# endpoint must return 404 to prevent information disclosure (existence of
# property, error class differentiation, etc.).
class IdorProtectionTest < ActionDispatch::IntegrationTest
  setup do
    # Establish session as fixture guest user
    get start_onboarding_url
    @session_user = inherit_fixture_guest_ownership

    # An unrelated user with their own property the session user must NOT touch
    @other_user = users(:guest_two)
    @other_property = properties(:basement_villa)
    UserProperty.find_or_create_by!(user: @other_user, property: @other_property)

    # Sanity: session user must not own @other_property
    assert_not @session_user.user_properties.exists?(property: @other_property),
      "fixture setup error: session user must not own @other_property"
  end

  test "GET /properties/:id returns 404 for other user's property" do
    get property_url(@other_property)
    assert_response :not_found
  end

  test "POST /properties/:id/documents returns 404 for other user's property" do
    pdf = fixture_file_upload("test.pdf", "application/pdf")
    post property_documents_path(@other_property), params: { documents: [ pdf ] }
    assert_response :not_found
  end

  test "DELETE /properties/:id/documents/:doc_id returns 404 for other user's property" do
    pdf_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("%PDF-1.4 test"),
      filename: "test.pdf",
      content_type: "application/pdf"
    )
    @other_property.documents.attach(pdf_blob)
    attachment = @other_property.documents.first

    delete property_document_path(@other_property, attachment)
    assert_response :not_found
  end

  test "POST /properties/:id/inspections/start returns 404 for other user's property" do
    post property_inspections_start_url(@other_property)
    assert_response :not_found
  end

  test "GET /properties/:id/inspections/tabs/:tab returns 404 for other user's property" do
    get edit_property_inspections_tab_url(@other_property, tab_key: "rights_analysis")
    assert_response :not_found
  end

  test "PATCH /properties/:id/inspections/tabs/:tab returns 404 for other user's property" do
    patch property_inspections_tab_url(@other_property, tab_key: "rights_analysis"), params: {}
    assert_response :not_found
  end

  test "GET /properties/:id/inspections/grade returns 404 for other user's property" do
    get property_inspections_grade_url(@other_property)
    assert_response :not_found
  end

  test "PATCH /properties/:id/inspections/source_doc_review returns 404 for other user's property" do
    patch property_inspections_source_doc_review_url(@other_property)
    assert_response :not_found
  end

  test "POST /properties/:id/analyses/retry returns 404 for other user's property" do
    post property_analysis_retry_url(@other_property)
    assert_response :not_found
  end

  test "POST /properties/:id/analyses/retry must not enqueue PdfAnalysisJob for other user's property" do
    assert_no_enqueued_jobs only: PdfAnalysisJob do
      post property_analysis_retry_url(@other_property)
    end
  end

  test "IDOR 404 must not enqueue AI jobs even when other user pre-attached docs" do
    # Other user has already attached PDFs (their analysis is ready). A naive
    # implementation would let session user trigger PdfAnalysisJob on those
    # docs and burn AI quota. set_user_property must reject before reaching
    # the documents.attached? branch.
    pdf_blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("%PDF-1.4 test"),
      filename: "test.pdf",
      content_type: "application/pdf"
    )
    @other_property.documents.attach(pdf_blob)

    assert_no_enqueued_jobs only: PdfAnalysisJob do
      post property_inspections_start_url(@other_property)
    end
  end

  test "IDOR 404 must not attach documents (no side effects)" do
    pdf = fixture_file_upload("test.pdf", "application/pdf")
    assert_no_difference "@other_property.documents.count" do
      post property_documents_path(@other_property), params: { documents: [ pdf ] }
    end
  end
end
