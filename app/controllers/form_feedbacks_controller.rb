# frozen_string_literal: true

class FormFeedbacksController < ApplicationController
  before_action :set_form_definition

  def create
    @feedback = @form_definition.form_feedbacks.build(feedback_params)
    @feedback.user = current_user if user_signed_in?
    @feedback.session_id = session.id.to_s unless user_signed_in?

    respond_to do |format|
      if @feedback.save
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("feedback-form-container", partial: "form_feedbacks/success"),
            turbo_stream.update("feedback-modal-title", "Thank You!")
          ]
        end
        format.html { redirect_to form_path(@form_definition), notice: "Thank you for your feedback!" }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "feedback-form-container",
            partial: "form_feedbacks/form",
            locals: { form_definition: @form_definition, feedback: @feedback }
          )
        end
        format.html { redirect_to form_path(@form_definition), alert: "Could not submit feedback. Please try again." }
      end
    end
  end

  private

  def set_form_definition
    @form_definition = FormDefinition.find(params[:form_definition_id])
  end

  def feedback_params
    params.require(:form_feedback).permit(:rating, :comment, issue_types: [])
  end
end
