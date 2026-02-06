# frozen_string_literal: true

class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
  end

  def update
    @user = current_user

    respond_to do |format|
      if @user.update(profile_params)
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "profile-status",
            partial: "profiles/status",
            locals: { message: "Profile saved", status: :success }
          )
        end
        format.html { redirect_to profile_path, notice: "Profile updated successfully." }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "profile-status",
            partial: "profiles/status",
            locals: { message: "Failed to save", status: :error }
          )
        end
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  # Valid tutorial identifiers - whitelist to prevent arbitrary data injection
  VALID_TUTORIALS = %w[
    welcome_tour
    form_wizard_intro
    form_filling_basics
    pdf_generation
    workflow_intro
    data_sharing
    auto_save_demo
    keyboard_shortcuts
    accessibility_features
  ].freeze

  def tutorial_completed
    tutorial_id = params[:tutorial_id]

    unless tutorial_id.present? && VALID_TUTORIALS.include?(tutorial_id)
      head :bad_request
      return
    end

    current_user.complete_tutorial!(tutorial_id)
    head :ok
  end

  private

  def profile_params
    params.require(:user).permit(
      :full_name, :phone, :address, :city, :state, :zip_code, :date_of_birth
    )
  end
end
