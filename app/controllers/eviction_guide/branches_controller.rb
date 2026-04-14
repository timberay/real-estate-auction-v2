module EvictionGuide
  class BranchesController < ApplicationController
    def show
      @branch = EvictionStep.branch.find_by!(code: params[:code])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
  end
end
