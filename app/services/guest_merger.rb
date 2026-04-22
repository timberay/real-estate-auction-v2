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
    end
  end

  def merge_prefer_guest(reflection)
    if reflection.macro == :has_one
      association = @from.public_send(reflection.name)
      @to.public_send(reflection.name)&.destroy
      association&.update!(user_id: @to.id)
    else
      @from.public_send(reflection.name).update_all(user_id: @to.id)
    end
  end
end
