# frozen_string_literal: true

class FormsController < ApplicationController
  include PdfHandling
  include FormDisplay
  include FormResponseHandler

  before_action :set_form_definition, only: [ :show, :update, :preview, :download, :toggle_wizard, :apply_template, :clear_template, :send_email ]

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
    load_form_display_data

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
      respond_with_autosave(@submission, redirect_path: form_path(@form_definition.code))
    else
      respond_with_autosave_error(@submission) { load_form_display_data }
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

  def apply_template
    @submission = find_or_create_submission(@form_definition)
    template_id = params[:template_id]
    customizations = params[:customizations] || {}

    applier = Templates::Applier.new(
      template_id: template_id,
      submission: @submission,
      customizations: customizations
    )

    result = applier.apply

    respond_to do |format|
      if result[:success]
        format.html { redirect_to form_path(@form_definition.code), notice: "Template applied successfully!" }
        format.json { render json: result, status: :ok }
        format.turbo_stream do
          flash.now[:notice] = "Template applied successfully!"
          redirect_to form_path(@form_definition.code)
        end
      else
        format.html { redirect_to form_path(@form_definition.code), alert: result[:errors].join(", ") }
        format.json { render json: result, status: :unprocessable_entity }
        format.turbo_stream do
          flash.now[:alert] = result[:errors].join(", ")
          redirect_to form_path(@form_definition.code)
        end
      end
    end
  end

  def clear_template
    @submission = find_or_create_submission(@form_definition)

    # Remove template metadata and prefilled fields
    if @submission.form_data["_template_metadata"].present?
      template_id = @submission.form_data.dig("_template_metadata", "template_id")
      template = Templates::Loader.instance.find(template_id)

      # Get prefill keys to clear
      if template
        form_code = @form_definition.code.to_sym
        prefills = template.dig(:prefills, :default, form_code) || {}

        # Clear prefilled fields
        new_data = @submission.form_data.except(*prefills.keys.map(&:to_s), "_template_metadata")
        @submission.update!(form_data: new_data)
      else
        @submission.update!(form_data: @submission.form_data.except("_template_metadata"))
      end
    end

    respond_to do |format|
      format.html { redirect_to form_path(@form_definition.code), notice: "Template cleared" }
      format.json { render json: { success: true }, status: :ok }
    end
  end

  def send_email
    unless user_signed_in?
      return respond_to do |format|
        format.html { redirect_to new_user_registration_path, alert: "Please create an account to receive your form by email." }
        format.json do
          render json: {
            success: false,
            requires_signup: true,
            message: "Create a free account to receive your completed form by email. Your progress will be saved!",
            signup_url: new_user_registration_path,
            login_url: new_user_session_path
          }, status: :unauthorized
        end
      end
    end

    @submission = find_or_create_submission(@form_definition)

    # Queue the email delivery job
    FormEmailJob.perform_later(
      user_id: current_user.id,
      submission_id: @submission.id,
      submission_type: @submission.class.name
    )

    respond_to do |format|
      format.html { redirect_to form_path(@form_definition.code), notice: "Your form has been sent to #{current_user.email}!" }
      format.json do
        render json: {
          success: true,
          message: "Your completed #{@form_definition.code} form is on its way to #{current_user.email}!",
          email: current_user.email
        }, status: :ok
      end
    end
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
    # Security: Only permit fields that are defined for this form
    # This prevents mass assignment attacks by restricting to known field names
    permitted_fields = @form_definition.field_definitions.pluck(:name)
    params.require(:submission).permit(*permitted_fields).to_h
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
