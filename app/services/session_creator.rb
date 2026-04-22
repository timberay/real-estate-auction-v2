class SessionCreator
  def initialize(current_guest:, profile:)
    @current_guest = current_guest
    @profile = profile
  end

  def call
    ActiveRecord::Base.transaction(joinable: false) do
      begin
        ActiveRecord::Base.connection.execute("BEGIN IMMEDIATE")
      rescue ActiveRecord::StatementInvalid
        # nested transaction (savepoint in tests) — BEGIN IMMEDIATE not applicable
      end
      dispatch
    end
  end

  private

  def dispatch
    if (identity = Identity.find_by(provider: @profile.provider, uid: @profile.uid))
      return attach_and_merge(identity.user)
    end
    # Case B/C added in later tasks
    raise NotImplementedError
  end

  def attach_and_merge(target_user)
    GuestMerger.new(from: @current_guest, to: target_user).call if @current_guest != target_user
    stamp_terms(target_user)
    target_user
  end

  def stamp_terms(user)
    user.update!(terms_accepted_at: Time.current) if user.terms_accepted_at.nil?
  end
end
