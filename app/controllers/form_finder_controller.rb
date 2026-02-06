# frozen_string_literal: true

class FormFinderController < ApplicationController
  before_action :set_engine

  def show
    @progress = @engine.progress
    @current_step = @engine.current_step
    @answers = @engine.answers

    if @engine.at_final_step?
      recommender = FormFinder::Recommender.new(@answers)
      @recommendation = recommender.recommend
    end
  end

  def update
    @engine.advance(finder_params)
    save_engine_state

    respond_to do |format|
      format.turbo_stream { render_step_update }
      format.html { redirect_to form_finder_path }
    end
  end

  def back
    @engine.go_back
    save_engine_state

    respond_to do |format|
      format.turbo_stream { render_step_update }
      format.html { redirect_to form_finder_path }
    end
  end

  def restart
    @engine.restart
    save_engine_state

    respond_to do |format|
      format.turbo_stream { render_step_update }
      format.html { redirect_to form_finder_path }
    end
  end

  private

  def set_engine
    @engine = FormFinder::Engine.new(session[:form_finder])
  end

  def save_engine_state
    session[:form_finder] = @engine.to_session
  end

  def finder_params
    params.permit(:role, :situation, :multiple_parties, :needs_fee_waiver).to_h
  end

  def render_step_update
    @progress = @engine.progress
    @current_step = @engine.current_step
    @answers = @engine.answers

    if @engine.at_final_step?
      recommender = FormFinder::Recommender.new(@answers)
      @recommendation = recommender.recommend
    end

    render turbo_stream: turbo_stream.replace(
      "form_finder_content",
      partial: "form_finder/step_#{@current_step}",
      locals: {
        progress: @progress,
        current_step: @current_step,
        answers: @answers,
        recommendation: @recommendation
      }
    )
  end
end
