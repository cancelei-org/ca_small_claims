# frozen_string_literal: true

# Helper methods for displaying form difficulty and time estimates.
#
# Usage in views:
#   <%= difficulty_badge(@form) %>
#   <%= time_estimate_badge(@form) %>
#   <%= form_estimates_badges(@form) %>
#
module FormEstimatesHelper
  # Difficulty level colors (using DaisyUI/Tailwind classes)
  DIFFICULTY_COLORS = {
    easy: {
      badge: "badge-success",
      bg: "bg-success/10",
      text: "text-success",
      border: "border-success/30"
    },
    medium: {
      badge: "badge-warning",
      bg: "bg-warning/10",
      text: "text-warning",
      border: "border-warning/30"
    },
    complex: {
      badge: "badge-error",
      bg: "bg-error/10",
      text: "text-error",
      border: "border-error/30"
    }
  }.freeze

  # Renders a difficulty badge with icon and color
  # @param form [FormDefinition] The form to display difficulty for
  # @param size [Symbol] Badge size (:sm, :md, :lg)
  # @param show_icon [Boolean] Whether to show the gauge icon
  # @return [String] HTML for the difficulty badge
  def difficulty_badge(form, size: :sm, show_icon: true)
    level = form.difficulty_level
    label = form.difficulty_label
    colors = DIFFICULTY_COLORS[level]

    size_class = case size
    when :xs then "badge-xs"
    when :sm then "badge-sm"
    when :lg then "badge-lg"
    else ""
    end

    content_tag(:span, class: "badge #{colors[:badge]} #{size_class} gap-1") do
      concat(difficulty_icon) if show_icon
      concat(label)
    end
  end

  # Renders a time estimate badge/pill
  # @param form [FormDefinition] The form to display time for
  # @param size [Symbol] Badge size (:sm, :md, :lg)
  # @param show_icon [Boolean] Whether to show the clock icon
  # @return [String] HTML for the time estimate badge
  def time_estimate_badge(form, size: :sm, show_icon: true)
    estimate = form.estimated_time

    size_class = case size
    when :xs then "badge-xs"
    when :sm then "badge-sm"
    when :lg then "badge-lg"
    else ""
    end

    content_tag(:span, class: "badge badge-ghost #{size_class} gap-1") do
      concat(clock_icon) if show_icon
      concat(estimate)
    end
  end

  # Renders both difficulty and time badges together
  # @param form [FormDefinition] The form to display estimates for
  # @param size [Symbol] Badge size
  # @return [String] HTML for both badges
  def form_estimates_badges(form, size: :sm)
    content_tag(:div, class: "flex items-center gap-2 flex-wrap") do
      concat(difficulty_badge(form, size: size))
      concat(time_estimate_badge(form, size: size))
    end
  end

  # Renders a compact inline estimate display (for cards)
  # @param form [FormDefinition] The form to display estimates for
  # @return [String] HTML for compact estimate display
  def compact_estimates(form)
    level = form.difficulty_level
    colors = DIFFICULTY_COLORS[level]

    content_tag(:div, class: "flex items-center gap-3 text-xs") do
      # Difficulty indicator
      concat(
        content_tag(:span, class: "flex items-center gap-1 #{colors[:text]}") do
          concat(difficulty_icon(size: :xs))
          concat(form.difficulty_label)
        end
      )

      # Separator dot
      concat(content_tag(:span, class: "text-base-content/30") { "|" })

      # Time estimate
      concat(
        content_tag(:span, class: "flex items-center gap-1 text-base-content/70") do
          concat(clock_icon(size: :xs))
          concat(form.estimated_time)
        end
      )
    end
  end

  # Renders detailed estimate card (for form show page header)
  # @param form [FormDefinition] The form to display estimates for
  # @return [String] HTML for detailed estimate card
  def detailed_estimates_card(form)
    level = form.difficulty_level
    colors = DIFFICULTY_COLORS[level]
    estimates = form.form_estimates

    content_tag(:div, class: "flex items-center gap-4 p-3 rounded-lg #{colors[:bg]} border #{colors[:border]}") do
      # Difficulty section
      concat(
        content_tag(:div, class: "flex items-center gap-2") do
          concat(difficulty_icon(size: :md, color: colors[:text]))
          concat(
            content_tag(:div) do
              concat(content_tag(:span, estimates[:difficulty_label], class: "font-semibold #{colors[:text]}"))
              concat(content_tag(:span, " difficulty", class: "text-base-content/70 text-sm"))
            end
          )
        end
      )

      # Separator
      concat(content_tag(:div, class: "w-px h-8 bg-base-content/20"))

      # Time section
      concat(
        content_tag(:div, class: "flex items-center gap-2") do
          concat(clock_icon(size: :md))
          concat(
            content_tag(:div) do
              concat(content_tag(:span, estimates[:estimated_time], class: "font-semibold text-base-content"))
              concat(content_tag(:span, " to complete", class: "text-base-content/70 text-sm"))
            end
          )
        end
      )

      # Field count (optional detail)
      if estimates[:total_fields].positive?
        concat(content_tag(:div, class: "w-px h-8 bg-base-content/20"))
        concat(
          content_tag(:div, class: "text-sm text-base-content/70") do
            concat(content_tag(:span, estimates[:total_fields], class: "font-semibold text-base-content"))
            concat(" fields")
          end
        )
      end
    end
  end

  private

  # SVG icon for difficulty (gauge/speedometer)
  def difficulty_icon(size: :sm, color: nil)
    size_class = case size
    when :xs then "w-3 h-3"
    when :sm then "w-4 h-4"
    when :md then "w-5 h-5"
    when :lg then "w-6 h-6"
    else "w-4 h-4"
    end

    color_class = color || "currentColor"

    content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24",
                "stroke-width": "1.5", stroke: "currentColor", class: "#{size_class} #{color}") do
      # Gauge/speedometer icon
      concat(tag.path("stroke-linecap": "round", "stroke-linejoin": "round",
                      d: "M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z"))
    end
  end

  # SVG icon for time (clock)
  def clock_icon(size: :sm)
    size_class = case size
    when :xs then "w-3 h-3"
    when :sm then "w-4 h-4"
    when :md then "w-5 h-5"
    when :lg then "w-6 h-6"
    else "w-4 h-4"
    end

    content_tag(:svg, xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24",
                "stroke-width": "1.5", stroke: "currentColor", class: size_class) do
      concat(tag.path("stroke-linecap": "round", "stroke-linejoin": "round",
                      d: "M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z"))
    end
  end
end
