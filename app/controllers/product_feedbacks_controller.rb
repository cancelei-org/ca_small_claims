# frozen_string_literal: true

class ProductFeedbacksController < ApplicationController
  include Pagy::Backend

  before_action :authenticate_user!
  before_action :set_product_feedback, only: %i[show vote unvote]

  def index
    @pagy, @product_feedbacks = pagy(
      ProductFeedback.recent.includes(:user),
      limit: 20
    )
    @my_feedbacks = current_user.product_feedbacks.recent.limit(5)
  end

  def show; end

  def new
    @product_feedback = ProductFeedback.new
    @product_feedback.category = params[:category] if params[:category].present?
  end

  def create
    @product_feedback = current_user.product_feedbacks.build(product_feedback_params)

    respond_to do |format|
      if @product_feedback.save
        ProductFeedbackMailer.admin_notification(@product_feedback).deliver_later

        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("product-feedback-form", partial: "product_feedbacks/success", locals: { product_feedback: @product_feedback }),
            turbo_stream.update("product-feedback-modal-title", "Thank You!")
          ]
        end
        format.html { redirect_to product_feedbacks_path, notice: "Thank you for your feedback!" }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "product-feedback-form",
            partial: "product_feedbacks/form",
            locals: { product_feedback: @product_feedback }
          )
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def vote
    if @product_feedback.vote_by(current_user)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "product-feedback-#{@product_feedback.id}-vote",
            partial: "product_feedbacks/vote_button",
            locals: { product_feedback: @product_feedback.reload }
          )
        end
        format.html { redirect_to @product_feedback, notice: "Vote recorded!" }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to @product_feedback, alert: "You have already voted for this feedback." }
      end
    end
  end

  def unvote
    if @product_feedback.unvote_by(current_user)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "product-feedback-#{@product_feedback.id}-vote",
            partial: "product_feedbacks/vote_button",
            locals: { product_feedback: @product_feedback.reload }
          )
        end
        format.html { redirect_to @product_feedback, notice: "Vote removed." }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to @product_feedback, alert: "Could not remove vote." }
      end
    end
  end

  private

  def set_product_feedback
    @product_feedback = ProductFeedback.find(params[:id])
  end

  def product_feedback_params
    params.require(:product_feedback).permit(:title, :description, :category, attachments: [])
  end
end
