class PdfExportService
  def self.call(html:)
    new(html: html).call
  end

  def initialize(html:)
    @html = html
  end

  def call
    Playwright.create(playwright_cli_executable_path: find_playwright_cli) do |playwright|
      launch_options = { headless: true, args: chromium_args }
      launch_options[:executablePath] = chromium_executable if chromium_executable

      playwright.chromium.launch(**launch_options) do |browser|
        page = browser.new_page
        page.set_content(@html, waitUntil: "networkidle")
        page.pdf(
          format: "A4",
          margin: { top: "20mm", bottom: "20mm", left: "15mm", right: "15mm" },
          printBackground: true
        )
      end
    end
  end

  private

  def chromium_executable
    ENV.fetch("PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH", nil)
  end

  def chromium_args
    %w[--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage]
  end

  def find_playwright_cli
    ENV.fetch("PLAYWRIGHT_CLI_EXECUTABLE_PATH", "npx playwright")
  end
end
