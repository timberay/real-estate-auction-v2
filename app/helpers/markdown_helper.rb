module MarkdownHelper
  def markdown(text)
    @md_renderer ||= Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(safe_links_only: true, filter_html: true),
      tables: true,
      fenced_code_blocks: true,
      autolink: true,
      no_intra_emphasis: true
    )
    @md_renderer.render(text).html_safe
  end
end
