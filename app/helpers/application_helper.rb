module ApplicationHelper
  include Pagy::Frontend

  # SEO meta tags helper
  def meta_tags
    defaults = {
      title: "California Small Claims Court Forms",
      description: "Free online tool to fill out California Small Claims Court forms. Generate print-ready PDFs for your court case.",
      image: image_url("og-image.png"),
      url: request.original_url
    }

    meta = defaults.merge(content_for(:meta_tags) || {})
    meta[:full_title] = meta[:title] == defaults[:title] ? meta[:title] : "#{meta[:title]} | CA Small Claims"

    meta
  end

  # Set page-specific meta tags
  def set_meta_tags(options = {})
    content_for(:meta_tags) { options }
  end
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
      ],
      accessibility: [
        { id: "high-contrast-light", name: "High Contrast Light", description: "WCAG AAA compliant" },
        { id: "high-contrast-dark", name: "High Contrast Dark", description: "WCAG AAA compliant" }
      ]
    }
  end

  # Check if a theme is a dark theme
  def dark_theme?(theme_id)
    dark_ids = available_themes[:dark].map { |t| t[:id] }
    dark_ids << "high-contrast-dark"
    dark_ids.include?(theme_id)
  end

  # Get all theme IDs as a flat array
  def all_theme_ids
    available_themes.values.flatten.map { |t| t[:id] }
  end
end
