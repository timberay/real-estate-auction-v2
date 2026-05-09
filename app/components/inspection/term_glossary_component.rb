module Inspection
  class TermGlossaryComponent < ViewComponent::Base
    def initialize(text:)
      @text = text.to_s
    end

    def annotated_html
      glossary = self.class.glossary
      escaped = ERB::Util.h(@text)
      glossary.each do |term, definition|
        escaped = escaped.gsub(term) do
          %(<span class="cursor-help underline decoration-dotted decoration-zinc-400 underline-offset-2 text-blue-700 dark:text-blue-300" ) +
            %(data-controller="glossary" ) +
            %(data-action="click->glossary#show" ) +
            %(data-glossary-term="#{ERB::Util.h(term)}" ) +
            %(data-glossary-definition-value="#{ERB::Util.h(definition)}">#{term}</span>)
        end
      end
      escaped.html_safe
    end

    def self.glossary
      @glossary ||= JSON.parse(Rails.root.join("db/seeds/glossary.json").read).freeze
    end
  end
end
