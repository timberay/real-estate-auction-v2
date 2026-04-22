class GuestMerger
  def initialize(from:, to:)
    @from = from
    @to = to
  end

  def call
    ActiveRecord::Base.transaction do
      User.mergeable_reflections.each { |reflection| merge(reflection) }
      @from.destroy!
    end
  rescue ActiveRecord::ActiveRecordError => e
    raise Auth::MergeError, e.message
  end

  private

  def merge(reflection)
    case reflection.options[:merge_policy]
    when :prefer_guest then merge_prefer_guest(reflection)
    when :keep_target  then merge_keep_target(reflection)
    end
  end

  def merge_prefer_guest(reflection)
    if reflection.macro == :has_one
      association = @from.public_send(reflection.name)
      @to.public_send(reflection.name)&.destroy
      association&.update!(user_id: @to.id)
    else
      delete_target_collisions(reflection)
      @from.public_send(reflection.name).update_all(user_id: @to.id)
    end
  end

  def merge_keep_target(reflection)
    if reflection.macro == :has_one
      @from.public_send(reflection.name)&.destroy
    else
      delete_guest_collisions(reflection)
      @from.public_send(reflection.name).update_all(user_id: @to.id)
    end
  end

  def delete_guest_collisions(reflection)
    natural_key = Array(reflection.options[:natural_key])
    return if natural_key.empty?

    target_rows = @to.public_send(reflection.name).pluck(*natural_key)
    return if target_rows.empty?

    guest_scope = @from.public_send(reflection.name)
    if natural_key.length == 1
      guest_scope.where(natural_key.first => target_rows).delete_all
    else
      target_rows.each do |values|
        conditions = natural_key.zip(Array(values)).to_h
        guest_scope.where(conditions).delete_all
      end
    end
  end

  def delete_target_collisions(reflection)
    natural_key = Array(reflection.options[:natural_key])
    return if natural_key.empty?

    guest_rows = @from.public_send(reflection.name).pluck(*natural_key)
    return if guest_rows.empty?

    target_scope = @to.public_send(reflection.name)
    if natural_key.length == 1
      target_scope.where(natural_key.first => guest_rows).delete_all
    else
      guest_rows.each do |values|
        conditions = natural_key.zip(Array(values)).to_h
        target_scope.where(conditions).delete_all
      end
    end
  end
end
