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

  private

  def profile_params
    params.require(:user).permit(
      :full_name, :phone, :address, :city, :state, :zip_code, :date_of_birth
    )
  end
end
