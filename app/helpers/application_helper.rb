module ApplicationHelper
  include Pagy::Frontend
  # Returns the current theme for the user
  # Priority: session > user preference > default
  def current_theme
    return session[:theme_preference] if session[:theme_preference].present?
    return current_user.theme_preference if user_signed_in? && current_user.respond_to?(:theme_preference) && current_user.theme_preference.present?

    "light" # Default theme
  end

  # Returns all available themes organized by category
  # Uses DaisyUI's built-in themes for consistency
  def available_themes
    {
      light: [
        { id: "light", name: "Light" },
        { id: "cupcake", name: "Cupcake" },
        { id: "emerald", name: "Emerald" },
        { id: "corporate", name: "Corporate" },
        { id: "garden", name: "Garden" }
      ],
      dark: [
        { id: "dark", name: "Dark" },
        { id: "night", name: "Night" },
        { id: "dracula", name: "Dracula" },
        { id: "business", name: "Business" },
        { id: "forest", name: "Forest" }
      ]
    }
  end

  # Check if a theme is a dark theme
  def dark_theme?(theme_id)
    available_themes[:dark].any? { |t| t[:id] == theme_id }
  end

  # Get all theme IDs as a flat array
  def all_theme_ids
    available_themes.values.flatten.map { |t| t[:id] }
  end
end
