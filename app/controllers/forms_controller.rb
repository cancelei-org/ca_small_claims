# frozen_string_literal: true

class FormsController < ApplicationController
  include SessionStorage
  include PdfHandling

  before_action :set_form_definition, only: [ :show, :update, :preview, :download, :toggle_wizard ]

  def index
    @forms = FormDefinition.active.includes(:category)
    @categories = Category.active.where.not(parent_id: nil).ordered

    if params[:category].present?
      @forms = @forms.by_category(params[:category])
      @current_category = Category.find_by(slug: params[:category])
    end

    @forms = @forms.search(params[:search]) if params[:search].present?

    # Sort by popularity or default order
    @sort_by = params[:sort] || "default"
    @forms = case @sort_by
    when "popular"
      @forms.by_popularity
    else
      @forms.ordered
    end

    # Get popular form IDs for badges (top 5 most used)
    @popular_form_ids = FormDefinition.active.popular(5).pluck(:id)
  end

  def show
    @submission = find_or_create_submission(@form_definition)
    @sections = @form_definition.sections
    @field_definitions = @form_definition.field_definitions.by_position

    # Wizard mode support
    @wizard_mode = wizard_mode_enabled?
    @skip_filled = skip_filled_enabled?

    return unless @wizard_mode
      filter_service = Forms::FieldFilterService.new(@form_definition, @submission, current_user)
      @wizard_fields = filter_service.wizard_fields(skip_filled: @skip_filled)
      @total_wizard_fields = filter_service.wizard_field_count(skip_filled: false)
      @filled_count = filter_service.filled_fields.count
  end

  def toggle_wizard
    session[:wizard_mode] = !session[:wizard_mode]
    redirect_to form_path(@form_definition.code, skip_filled: params[:skip_filled])
  end

  def update
    @submission = find_or_create_submission(@form_definition)

    if @submission.update_fields(submission_params)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "autosave-status",
            partial: "shared/autosave_status",
            locals: { saved_at: Time.current }
          )
        end
        format.json { render json: { success: true, saved_at: Time.current.iso8601 } }
        format.html { redirect_to form_path(@form_definition.code), notice: "Form saved" }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          @sections = @form_definition.sections
          @field_definitions = @form_definition.field_definitions.by_position
          render :show, status: :unprocessable_entity
        end
        format.json { render json: { success: false, errors: @submission.errors.full_messages }, status: :unprocessable_entity }
        format.html do
          @sections = @form_definition.sections
          @field_definitions = @form_definition.field_definitions.by_position
          render :show, status: :unprocessable_entity
        end
      end
    end
  end

  def preview
    @submission = find_or_create_submission(@form_definition)
    send_pdf_inline(@submission)
  end

  def download
    @submission = find_or_create_submission(@form_definition)
    send_pdf_download(@submission)
  end

  private

  def set_form_definition
    # FriendlyId lookup with fallback to code for backward compatibility
    @form_definition = FormDefinition.friendly.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    # Fallback to code lookup (handles uppercase codes like SC-100)
    @form_definition = FormDefinition.find_by!(code: params[:id].upcase)
  end

  def submission_params
    params.require(:submission).permit!.to_h
  end

  def wizard_mode_enabled?
    # Check URL param first, then session, default to true for wizard mode
    if params[:wizard].present?
      params[:wizard] == "true"
    elsif session[:wizard_mode].nil?
      true # Default to wizard mode
    else
      session[:wizard_mode]
    end
  end

  def skip_filled_enabled?
    # Only allow skip_filled for authenticated users
    return false unless user_signed_in?

    params[:skip_filled] == "true"
  end

  # Override PdfHandling concern method
  def pdf_failure_redirect_path(_submission)
    form_path(@form_definition.code)
  end
end
