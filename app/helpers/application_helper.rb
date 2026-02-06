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
    dark_ids = available_themes[:dark].pluck(:id)
    dark_ids << "high-contrast-dark"
    dark_ids.include?(theme_id)
  end

  # Get all theme IDs as a flat array
  def all_theme_ids
    available_themes.values.flatten.pluck(:id)
  end

  # Product Feedback category helpers
  def category_emoji(category)
    {
      "general" => "💬",
      "bug" => "🐛",
      "feature" => "✨",
      "partnership" => "🤝"
    }[category.to_s] || "💬"
  end

  def render_category_icon(category)
    icons = {
      "general" => '<svg class="w-4 h-4 inline-block" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" /></svg>',
      "bug" => '<svg class="w-4 h-4 inline-block" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>',
      "feature" => '<svg class="w-4 h-4 inline-block" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" /></svg>',
      "partnership" => '<svg class="w-4 h-4 inline-block" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" /></svg>'
    }
    icons[category.to_s]&.html_safe || ""
  end
end
