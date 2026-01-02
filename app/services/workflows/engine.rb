# frozen_string_literal: true

module Workflows
  class Engine
    attr_reader :workflow, :session_id, :user, :workflow_session_id

    def initialize(workflow, session_id:, user: nil, workflow_session_id: nil)
      @workflow = workflow
      @session_id = session_id
      @user = user
      @workflow_session_id = workflow_session_id || SecureRandom.uuid
    end

    def start
      first_step = @workflow.first_step
      return nil unless first_step

      create_submission_for_step(first_step)
    end

    def current_submission
      submissions.drafts.order(:updated_at).last
    end

    def current_step
      current = current_submission
      return nil unless current

      @workflow.step_at(current.workflow_step_position)
    end

    def advance(form_data = {})
      current = current_submission
      return nil unless current

      current.update_fields(form_data) if form_data.present?
      current.complete!

      next_step = find_next_applicable_step(current.workflow_step_position)
      return nil unless next_step

      create_submission_for_step(next_step)
    end

    def go_back
      current = current_submission
      return nil unless current

      prev_step = @workflow.previous_step(current.workflow_step_position)
      return nil unless prev_step

      # Find existing submission for previous step
      previous_submission = submissions.find_by(
        workflow_step_position: prev_step.position
      )

      if previous_submission
        previous_submission.update!(status: "draft")
        previous_submission
      else
        create_submission_for_step(prev_step)
      end
    end

    def go_to_step(position)
      step = @workflow.step_at(position)
      return nil unless step

      existing = submissions.find_by(workflow_step_position: position)

      if existing
        existing.update!(status: "draft")
        existing
      else
        create_submission_for_step(step)
      end
    end

    def progress
      completed = submissions.completed.count
      total = @workflow.total_steps
      current_pos = current_submission&.workflow_step_position || 0

      {
        current_step: current_pos,
        completed_steps: completed,
        total_steps: total,
        percentage: total.positive? ? (completed.to_f / total * 100).round : 0,
        steps: workflow_steps_status
      }
    end

    def workflow_steps_status
      @workflow.workflow_steps.map do |step|
        submission = submissions.find_by(workflow_step_position: step.position)

        {
          position: step.position,
          name: step.display_name,
          form_code: step.form_definition.code,
          status: submission&.status || "pending",
          required: step.required
        }
      end
    end

    def all_submissions
      submissions.includes(:form_definition).order(:workflow_step_position)
    end

    def completed_submissions
      submissions.completed.includes(:form_definition).order(:workflow_step_position)
    end

    def shared_data
      submissions.completed.each_with_object({}) do |sub, data|
        data.merge!(sub.shared_data)
      end
    end

    def complete?
      required_positions = @workflow.required_steps.pluck(:position)

      return false if required_positions.empty?

      completed_positions = submissions.completed.pluck(:workflow_step_position)

      (required_positions - completed_positions).empty?
    end

    def generate_all_pdfs
      completed_submissions.map do |submission|
        {
          form_code: submission.form_definition.code,
          path: submission.generate_pdf
        }
      end
    end

    private

    def submissions
      base = Submission.where(
        workflow_session_id: @workflow_session_id,
        workflow: @workflow
      )

      @user ? base.where(user: @user) : base.where(session_id: @session_id)
    end

    def find_next_applicable_step(current_position)
      @workflow.workflow_steps.where("position > ?", current_position).find do |step|
        step.should_show?(shared_data)
      end
    end

    def create_submission_for_step(step)
      prefilled_data = prefill_from_shared_data(step)

      Submission.create!(
        user: @user,
        session_id: @session_id,
        form_definition: step.form_definition,
        workflow: @workflow,
        workflow_step_position: step.position,
        workflow_session_id: @workflow_session_id,
        form_data: prefilled_data,
        status: "draft"
      )
    end

    def prefill_from_shared_data(step)
      data = step.prefill_data(shared_data)

      # Also prefill from shared field keys
      step.form_definition.field_definitions
        .where.not(shared_field_key: nil)
        .each do |field|
          data[field.name] = shared_data[field.shared_field_key] if shared_data.key?(field.shared_field_key) && !data.key?(field.name)
        end

      data
    end
  end
end
