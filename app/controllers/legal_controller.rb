class LegalController < ApplicationController
  skip_before_action :require_authenticated_user

  around_action :use_ko_locale

  def terms
    @legal_content = read_legal_file("legal_terms.md")
  end

  def privacy
    @legal_content = read_legal_file("legal_privacy.md")
  end

  private

  def use_ko_locale(&)
    I18n.with_locale(:ko, &)
  end

  def read_legal_file(filename)
    Rails.root.join("db/seeds", filename).read
  rescue Errno::ENOENT => e
    Rails.logger.error("Legal seed file missing: #{filename} (#{e.message})")
    "# 문서 준비 중\n\n잠시 후 다시 시도해 주세요."
  end
end
