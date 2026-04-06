# frozen_string_literal: true

class InputComponent < ViewComponent::Base
  INPUT_CLASSES = "w-full rounded-md border px-3 text-sm focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
  NORMAL_CLASSES = "border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100"
  ERROR_CLASSES = "border-red-500"

  SIZES = {
    sm: "h-8",
    md: "h-10",
    lg: "h-12"
  }.freeze

  def initialize(label:, name:, type: "text", value: nil, required: false, error: nil, help_text: nil, suffix: nil, inputmode: nil, placeholder: nil, size: :md, **html_options)
    @label = label
    @name = name
    @type = type
    @value = value
    @required = required
    @error = error
    @help_text = help_text
    @suffix = suffix
    @inputmode = inputmode
    @placeholder = placeholder
    @size = size
    @html_options = html_options
  end

  private

  def input_classes
    class_names(
      INPUT_CLASSES,
      SIZES[@size],
      @error.present? ? ERROR_CLASSES : NORMAL_CLASSES
    )
  end

  def input_attributes
    attrs = {
      type: @type,
      name: @name,
      value: @value,
      class: input_classes,
      placeholder: @placeholder
    }
    attrs[:required] = true if @required
    attrs[:inputmode] = @inputmode if @inputmode
    attrs.merge(@html_options)
  end
end
