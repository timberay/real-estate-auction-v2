class StepperComponent < ViewComponent::Base
  STEPS = [
    { key: :checklist, number: 1, label: "체크리스트" },
    { key: :report,    number: 2, label: "권리 분석" },
    { key: :rating,    number: 3, label: "등급 산정" }
  ].freeze

  def initialize(property:, user:, active_step:)
    @property = property
    @user = user
    @active_step = active_step
  end

  private

  def steps
    STEPS.map do |step|
      step.merge(
        status: step_status(step[:key]),
        url: step_url(step[:key])
      )
    end
  end

  def step_status(key)
    if key == @active_step
      :active
    elsif step_completed?(key)
      :completed
    else
      :pending
    end
  end

  def step_completed?(key)
    case key
    when :checklist then user_property&.analyzed_at.present?
    when :report then report.present?
    when :rating then user_property&.safety_rating.present?
    end
  end

  def step_url(key)
    case key
    when :checklist then helpers.edit_property_analyses_checklist_path(@property)
    when :report then helpers.property_analyses_report_path(@property)
    when :rating then helpers.property_analyses_rating_path(@property)
    end
  end

  def step_classes(step, index)
    base = "flex items-center justify-center gap-1.5 py-2.5 flex-1 transition-colors"

    shape = if index == 0
      "[clip-path:polygon(0_0,calc(100%-14px)_0,100%_50%,calc(100%-14px)_100%,0_100%)]"
    elsif index == steps.length - 1
      "-ml-2.5 [clip-path:polygon(0_0,100%_0,100%_100%,0_100%,14px_50%)] rounded-r-md"
    else
      "-ml-2.5 [clip-path:polygon(0_0,calc(100%-14px)_0,100%_50%,calc(100%-14px)_100%,0_100%,14px_50%)]"
    end

    color = case step[:status]
    when :completed then "bg-blue-900/50 text-blue-300"
    when :active    then "bg-blue-600 text-white font-semibold"
    when :pending   then "bg-slate-800 text-slate-500"
    end

    "#{base} #{shape} #{color}"
  end

  def user_property
    @user_property ||= UserProperty.find_by(user: @user, property: @property)
  end

  def report
    @report ||= RightsAnalysisReport.find_by(user: @user, property: @property)
  end
end
