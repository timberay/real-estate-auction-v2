class EvictionGuideController < ApplicationController
  def guide
    @main_steps = EvictionStep.main.ordered
  end

  def simulator
    @property = Property.find_by(id: params[:property_id])
    @properties = current_user.properties.order(created_at: :desc)
    @first_question = EvictionSimulatorQuestion.find_by(code: "Q1")
  end
end
