# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @featured_workflows = Workflow.active.ordered.limit(3)
    @popular_forms = FormDefinition.active
      .where(code: %w[SC-100 SC-120 SC-104 SC-130])
      .ordered
    @categories = Category.active.where.not(parent_id: nil).ordered
    @all_forms = FormDefinition.active.ordered.limit(8)
  end

  def forms_picker
    @forms = FormDefinition.active.ordered

    @forms = @forms.search(params[:search]) if params[:search].present?

    @forms = @forms.by_category(params[:category]) if params[:category].present?
    @forms = @forms.limit(12)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "forms-picker-results",
          partial: "home/forms_picker_results",
          locals: { forms: @forms }
        )
      end
      format.html do
        render partial: "home/forms_picker_results", locals: { forms: @forms }
      end
    end
  end

  def about
  end

  def help
  end

  def accessibility
  end
end
