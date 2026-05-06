module PropertyScopable
  extend ActiveSupport::Concern

  private

  # Loads @user_property and @property scoped to current_user.
  # Raises ActiveRecord::RecordNotFound (→ 404) when the requested property
  # is not in current_user's list. Use as a before_action on every
  # property-scoped endpoint to prevent IDOR.
  def set_user_property
    pid = params[:property_id] || params[:id]
    @user_property = current_user.user_properties.find_by!(property_id: pid)
    @property = @user_property.property
  end
end
