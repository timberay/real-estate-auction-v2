module Settings
  class BudgetSnapshotsController < ApplicationController
    def index
      @snapshots = current_user.budget_snapshots.order(version: :desc)
    end

    def show
      @snapshot = current_user.budget_snapshots.find(params[:id])
    end

    def compare
      ids = params[:ids]
      @snapshot_a = current_user.budget_snapshots.find(ids[0])
      @snapshot_b = current_user.budget_snapshots.find(ids[1])
      @diff = BudgetSnapshotService.compare(snapshot_a: @snapshot_a, snapshot_b: @snapshot_b)
    end

    def recalculate
      parent = current_user.budget_snapshots.find(params[:id])
      BudgetSnapshotService.recalculate(user: current_user, parent_snapshot: parent)
      redirect_to settings_budget_snapshots_url, notice: "현재 조건으로 재계산되었습니다."
    end
  end
end
