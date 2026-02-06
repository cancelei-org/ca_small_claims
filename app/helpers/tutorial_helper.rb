# frozen_string_literal: true

module TutorialHelper
  TUTORIAL_CONFIG_PATH = Rails.root.join("config/tutorials")

  # Renders the tutorial controller wrapper for a specific tutorial
  # Usage: <%= tutorial_wrapper("form_tutorial") do %> ... <% end %>
  def tutorial_wrapper(tutorial_id, &block)
    config = load_tutorial_config(tutorial_id)
    return capture(&block) if config.nil?

    steps = config.dig("tutorial", "steps") || []
    completed = tutorial_completed?(tutorial_id)

    content_tag(:div,
      capture(&block),
      data: {
        controller: "tutorial",
        tutorial_tutorial_id_value: tutorial_id,
        tutorial_steps_value: steps.to_json,
        tutorial_completed: completed.to_s,
        tutorial_show_dont_show_again_value: config.dig("settings", "show_dont_show_again") || true,
        tutorial_spotlight_padding_value: config.dig("settings", "spotlight_padding") || 12,
        tutorial_spotlight_radius_value: config.dig("settings", "spotlight_radius") || 8
      }
    )
  end

  # Check if user has completed a tutorial
  def tutorial_completed?(tutorial_id)
    return false unless user_signed_in?

    current_user.tutorial_completed?(tutorial_id)
  rescue NoMethodError
    # User model doesn't have tutorial tracking yet
    false
  end

  # Load tutorial configuration from YAML
  def load_tutorial_config(tutorial_id)
    config_path = TUTORIAL_CONFIG_PATH.join("#{tutorial_id}.yml")
    return nil unless File.exist?(config_path)

    YAML.load_file(config_path)
  rescue StandardError => e
    Rails.logger.error("Failed to load tutorial config #{tutorial_id}: #{e.message}")
    nil
  end

  # Render a "Take the tour" button for users who dismissed the tutorial
  def tutorial_restart_button(tutorial_id, options = {})
    button_class = options[:class] || "btn btn-ghost btn-sm gap-1"
    button_text = options[:text] || "Take the Tour"

    content_tag(:button,
      type: "button",
      class: button_class,
      data: {
        action: "click->tutorial#start"
      },
      title: "Start the guided tour"
    ) do
      safe_join([
        content_tag(:svg, class: "w-4 h-4", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
          content_tag(:path, nil,
            "stroke-linecap": "round",
            "stroke-linejoin": "round",
            "stroke-width": "2",
            d: "M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z")
        end,
        button_text
      ])
    end
  end
end
