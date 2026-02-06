# frozen_string_literal: true

module FormResponseHandler
  extend ActiveSupport::Concern

  private

  # Handle multi-format response for form submissions
  # @param success [Boolean] Whether the operation succeeded
  # @param options [Hash] Response options
  # @option options [Proc] :turbo_success Block to execute for successful turbo_stream
  # @option options [Proc] :turbo_error Block to execute for error turbo_stream
  # @option options [Hash] :json_success JSON response for success (default: { success: true })
  # @option options [Hash] :json_error JSON response for error (default: { success: false, errors: [] })
  # @option options [String] :redirect_path Path to redirect on HTML success
  # @option options [String] :redirect_notice Flash notice for redirect
  # @option options [Symbol] :error_template Template to render on HTML error (default: :show)
  # @option options [Proc] :before_error Block to execute before rendering error
  def respond_with_form_result(success, options = {})
    respond_to do |format|
      if success
        format.turbo_stream { instance_exec(&options[:turbo_success]) } if options[:turbo_success]
        format.json { render json: options[:json_success] || { success: true } }
        format.html { redirect_to options[:redirect_path], notice: options[:redirect_notice] } if options[:redirect_path]
      else
        format.turbo_stream do
          options[:before_error]&.call
          instance_exec(&options[:turbo_error]) if options[:turbo_error]
        end
        format.json do
          error_response = options[:json_error] || { success: false, errors: [] }
          render json: error_response, status: :unprocessable_entity
        end
        format.html do
          options[:before_error]&.call
          render options[:error_template] || :show, status: :unprocessable_entity
        end
      end
    end
  end

  # Simplified autosave response (common pattern for form autosave)
  # @param submission [Submission] The submission being updated
  # @param redirect_path [String] Path for HTML redirect on success
  def respond_with_autosave(submission, redirect_path:)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "autosave-status",
          partial: "shared/autosave_status",
          locals: { saved_at: Time.current }
        )
      end
      format.json { render json: { success: true, saved_at: Time.current.iso8601 } }
      format.html { redirect_to redirect_path, notice: "Form saved" }
    end
  end

  # Error response for autosave failures
  # @param submission [Submission] The submission with errors
  # @param error_template [Symbol] Template to render (default: :show)
  # @param before_render [Proc] Block to execute before rendering
  def respond_with_autosave_error(submission, error_template: :show, &before_render)
    respond_to do |format|
      format.turbo_stream do
        before_render&.call
        render error_template, status: :unprocessable_entity
      end
      format.json do
        render json: { success: false, errors: submission.errors.full_messages },
               status: :unprocessable_entity
      end
      format.html do
        before_render&.call
        render error_template, status: :unprocessable_entity
      end
    end
  end
end
