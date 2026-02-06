# frozen_string_literal: true

class Courthouse < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :address, presence: true
  validates :city, presence: true
  validates :county, presence: true
  validates :zip, presence: true, format: { with: /\A\d{5}(-\d{4})?\z/, message: "must be a valid ZIP code" }
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  validates :website_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_county, ->(county) { where("LOWER(county) = ?", county.to_s.downcase) }
  scope :by_city, ->(city) { where("LOWER(city) = ?", city.to_s.downcase) }
  scope :by_zip, ->(zip) { where("zip LIKE ?", "#{zip}%") }
  scope :with_coordinates, -> { where.not(latitude: nil, longitude: nil) }
  scope :ordered, -> { order(:county, :name) }

  # Class methods for searching
  def self.search(query)
    return none if query.blank?

    query = query.to_s.strip.downcase

    # Check if query looks like a ZIP code
    if query.match?(/^\d{5}$/)
      by_zip(query)
    else
      where(
        "LOWER(name) LIKE :q OR LOWER(city) LIKE :q OR LOWER(county) LIKE :q OR LOWER(address) LIKE :q",
        q: "%#{query}%"
      )
    end
  end

  # Returns list of unique counties with courthouses
  def self.counties
    active.distinct.pluck(:county).sort
  end

  # Returns list of unique cities with courthouses
  def self.cities
    active.distinct.pluck(:city).sort
  end

  # Full address for display
  def full_address
    "#{address}, #{city}, CA #{zip}"
  end

  # Check if courthouse has map coordinates
  def has_coordinates?
    latitude.present? && longitude.present?
  end

  # Returns data formatted for JSON API / JavaScript consumption
  def as_map_marker
    {
      id: id,
      name: name,
      address: full_address,
      city: city,
      county: county,
      phone: phone,
      hours: hours,
      website_url: website_url,
      latitude: latitude&.to_f,
      longitude: longitude&.to_f
    }
  end
end
