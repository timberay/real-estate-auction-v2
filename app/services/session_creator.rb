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
    if @profile.email.present? &&
       (existing = User.find_by(email: @profile.email, guest: false))
      Identity.find_or_create_by!(provider: @profile.provider, uid: @profile.uid) do |i|
        i.user = existing
        i.email = @profile.email
        i.raw_info = @profile.raw_info
      end
      return attach_and_merge(existing)
    end
    promote_guest
  end

  def promote_guest
    @current_guest.reload
    if @current_guest.guest?
      @current_guest.update!(
        guest: false,
        guest_token: nil,
        email: @profile.email,
        name: @profile.name,
        avatar_url: @profile.avatar_url,
        terms_accepted_at: Time.current
      )
    end
    upsert_identity
    @current_guest
  end

  def upsert_identity
    Identity.find_or_create_by!(provider: @profile.provider, uid: @profile.uid) do |i|
      i.user = @current_guest
      i.email = @profile.email
      i.raw_info = @profile.raw_info
    end
  rescue ActiveRecord::RecordNotUnique
    Identity.find_by!(provider: @profile.provider, uid: @profile.uid)
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
