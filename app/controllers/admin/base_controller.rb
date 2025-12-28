# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!

    layout "admin"

    private

    def authorize_admin!
      authorize :admin, :access?
    end
  end
end
