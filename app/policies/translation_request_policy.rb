class TranslationRequestPolicy < ApplicationPolicy
  def show?
    admin? && record.user_id == user.id
  end

  alias refresh_status? show?
  alias progress? show?
  alias prefer? show?
  alias export? show?
end
