# frozen_string_literal: true

class CourthousesController < ApplicationController
  def index
    @courthouses = Courthouse.active.ordered
    @counties = Courthouse.counties
    @cities = Courthouse.cities

    # Apply search filters
    if params[:search].present?
      @courthouses = @courthouses.search(params[:search])
    elsif params[:county].present?
      @courthouses = @courthouses.by_county(params[:county])
    elsif params[:city].present?
      @courthouses = @courthouses.by_city(params[:city])
    elsif params[:zip].present?
      @courthouses = @courthouses.by_zip(params[:zip])
    end

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "courthouse-results",
          partial: "courthouses/results",
          locals: { courthouses: @courthouses }
        )
      end
      format.json do
        render json: {
          courthouses: @courthouses.with_coordinates.map(&:as_map_marker),
          total: @courthouses.count
        }
      end
    end
  end

  def show
    @courthouse = Courthouse.find(params[:id])
    @nearby = find_nearby_courthouses(@courthouse)

    respond_to do |format|
      format.html
      format.json { render json: @courthouse.as_map_marker }
    end
  end

  # API endpoint for map markers
  def markers
    @courthouses = Courthouse.active.with_coordinates

    @courthouses = @courthouses.by_county(params[:county]) if params[:county].present?

    render json: @courthouses.map(&:as_map_marker)
  end

  private

  def find_nearby_courthouses(courthouse)
    return [] unless courthouse.has_coordinates?

    # Simple distance-based query (within ~50 miles / 0.7 degrees)
    Courthouse.active
      .with_coordinates
      .where.not(id: courthouse.id)
      .where(
        "ABS(latitude - ?) < 0.7 AND ABS(longitude - ?) < 0.7",
        courthouse.latitude,
        courthouse.longitude
      )
      .limit(5)
  end
end
