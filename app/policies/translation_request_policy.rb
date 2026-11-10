class TranslationRequestPolicy < ApplicationPolicy
  def show?
    admin? && record.user_id == user.id
  end

  alias refresh_status? show?
  alias prefer? show?
end
