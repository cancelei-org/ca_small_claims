# frozen_string_literal: true

class TemplatesController < ApplicationController
  # List all available quick fill templates
  def index
    @templates = Templates::Loader.instance.all

    respond_to do |format|
      format.html
      format.json { render json: @templates }
    end
  end

  # Show a specific template with full details
  def show
    @template = Templates::Loader.instance.find(params[:id])

    if @template.nil?
      respond_to do |format|
        format.html { redirect_to templates_path, alert: "Template not found" }
        format.json { render json: { error: "Template not found" }, status: :not_found }
      end
      return
    end

    respond_to do |format|
      format.html
      format.json { render json: @template }
    end
  end
end
