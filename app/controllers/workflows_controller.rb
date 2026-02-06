# frozen_string_literal: true

class WorkflowsController < ApplicationController
  include FormDisplay

  before_action :set_workflow, only: [ :show, :step, :advance, :back, :complete ]
  before_action :set_engine, only: [ :show, :step, :advance, :back, :complete ]

  def index
    @workflows = Workflow.active.includes(:workflow_steps).ordered

    @workflows = @workflows.by_category(params[:category]) if params[:category].present?
  end

  def show
    @current_submission = @engine.current_submission || @engine.start
    @progress = @engine.progress
    @current_step = @engine.current_step
    load_form_display_from_submission(@current_submission)
    @field_definitions = safe_field_definitions
  end

  def step
    @current_submission = @engine.current_submission
    @progress = @engine.progress
    @current_step = @engine.current_step
    load_form_display_from_submission(@current_submission)
    @field_definitions = safe_field_definitions

    return unless request.patch? && @current_submission
      @current_submission.update_fields(submission_params)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to workflow_path(@workflow) }
      end
  end

  def advance
    @current_submission = @engine.current_submission

    if @current_submission
      @current_submission.update_fields(submission_params) if params[:submission].present?
    end

    next_submission = @engine.advance

    if next_submission
      redirect_to workflow_path(@workflow)
    else
      redirect_to complete_workflow_path(@workflow)
    end
  end

  def back
    @engine.go_back
    redirect_to workflow_path(@workflow)
  end

  def complete
    @progress = @engine.progress
    @completed_submissions = @engine.completed_submissions

    unless @engine.complete?
      redirect_to workflow_path(@workflow),
        alert: "Please complete all required steps first."
    end
  end

  private

  def set_workflow
    @workflow = Workflow.find_by(slug: params[:id]) || Workflow.find(params[:id])
  end

  def set_engine
    workflow_session_key = "workflow_#{@workflow.id}_session"

    session[workflow_session_key] ||= SecureRandom.uuid

    @engine = Workflows::Engine.new(
      @workflow,
      session_id: form_session_id,
      user: current_user,
      workflow_session_id: session[workflow_session_key]
    )
  end

  def submission_params
    # Security: Only permit fields from the current workflow step's form
    # This prevents mass assignment attacks by restricting to known field names
    current_submission = @engine&.current_submission
    return {} unless current_submission&.form_definition

    permitted_fields = current_submission.form_definition.field_definitions.pluck(:name)
    params.require(:submission).permit(*permitted_fields).to_h
  end
end
