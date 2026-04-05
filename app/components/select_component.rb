# frozen_string_literal: true

class SelectComponent < ViewComponent::Base
  OptionItem = Data.define(:value, :label, :selected)

  SELECT_CLASSES = "w-full rounded-md border px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
  NORMAL_CLASSES = "border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100"
  ERROR_CLASSES = "border-red-500"

  def initialize(label:, name:, prompt: nil, error: nil, required: false, **html_options)
    @label = label
    @name = name
    @prompt = prompt
    @error = error
    @required = required
    @html_options = html_options
    @option_items = []
  end

  def with_option(value:, label:, selected: false)
    @option_items << OptionItem.new(value: value, label: label, selected: selected)
  end

  def before_render
    # Process content block to collect options
    content
  end

  private

  def option_items
    @option_items
  end

  def select_classes
    class_names(
      SELECT_CLASSES,
      @error.present? ? ERROR_CLASSES : NORMAL_CLASSES
    )
  end
end
