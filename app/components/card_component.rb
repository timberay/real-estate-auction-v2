# frozen_string_literal: true

class CardComponent < ViewComponent::Base
  renders_one :footer

  def initialize(title: nil, description: nil, **html_options)
    @title = title
    @description = description
    @html_options = html_options
  end

  private

  def container_classes
    class_names(
      "rounded-lg bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 shadow-sm",
      @html_options.delete(:class)
    )
  end

  def header?
    @title.present?
  end
end
