# frozen_string_literal: true

module Api
  class DocsController < Api::BaseController
    skip_before_action :authenticate_token!

    def show
      send_file Rails.root.join("docs", "api", "openapi.yml"), type: "text/yaml"
    end
  end
end
