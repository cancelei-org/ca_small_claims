# frozen_string_literal: true

class FormFeedbackPolicy < ApplicationPolicy
  def create?
    true # Anyone can submit feedback
  end

  def index?
    admin?
  end

  def show?
    admin?
  end

  def update?
    admin?
  end

  def acknowledge?
    admin?
  end

  def resolve?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.none
      end
    end
  end
end
