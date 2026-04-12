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
      unless ids.is_a?(Array) && ids.size >= 2
        redirect_to settings_budget_snapshots_path, alert: "비교할 스냅샷 2개를 선택해주세요."
        return
      end

      @snapshot_a = current_user.budget_snapshots.find(ids[0])
      @snapshot_b = current_user.budget_snapshots.find(ids[1])
      @diff = BudgetSnapshotService.compare(snapshot_a: @snapshot_a, snapshot_b: @snapshot_b)
    rescue ActiveRecord::RecordNotFound
      redirect_to settings_budget_snapshots_path, alert: "선택한 스냅샷을 찾을 수 없습니다."
    end

    def recalculate
      parent = current_user.budget_snapshots.find(params[:id])
      BudgetSnapshotService.recalculate(user: current_user, parent_snapshot: parent)
      redirect_to settings_budget_snapshots_url, notice: "현재 조건으로 재계산되었습니다."
    end
  end
end
