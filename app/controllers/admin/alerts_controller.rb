# frozen_string_literal: true

module Admin
  class AlertsController < BaseController
    def index
      @alerts = AlertLog.order(created_at: :desc).limit(200).group_by(&:severity)
    end
  end
end
