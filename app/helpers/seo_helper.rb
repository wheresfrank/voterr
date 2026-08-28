# frozen_string_literal: true

module SeoHelper
  CANONICAL_HOST = "www.voterr.tv"
  CANONICAL_ORIGIN = "https://www.voterr.tv"
  GITHUB_REPO_URL = "https://github.com/wheresfrank/voterr"
  GITHUB_PROFILE_URL = "https://github.com/wheresfrank"
  AUTHOR_NAME = "Frank Johnette"
  AUTHOR_URL = "https://frankjohnette.xyz"
  DEFAULT_TITLE = "Voterr — Plex movie-night voting"
  DEFAULT_DESCRIPTION = "Hosted Plex movie-night voting. Sign in with Plex, share one link, and let guests vote by name — no Plex login on their side, no Docker token, no self-hosting required."
  OG_IMAGE_PATH = "/og-image.jpg"
  OG_IMAGE_WIDTH = 1200
  OG_IMAGE_HEIGHT = 630

  def canonical_origin
    CANONICAL_ORIGIN
  end

  def canonical_page_url(path = request.path)
    return "#{CANONICAL_ORIGIN}/" if path.blank? || path == "/"

    "#{CANONICAL_ORIGIN}#{path}"
  end

  def seo_title
    content_for?(:title) ? content_for(:title) : DEFAULT_TITLE
  end

  def seo_description
    content_for?(:description) ? content_for(:description) : DEFAULT_DESCRIPTION
  end

  def seo_robots
    content_for?(:robots) ? content_for(:robots) : "index, follow"
  end

  def seo_image_url
    "#{CANONICAL_ORIGIN}#{OG_IMAGE_PATH}"
  end

  def json_ld_tag(data)
    json = data.is_a?(String) ? data : data.to_json
    # json_escape unicode-escapes <, >, and & so a value cannot break out of
    # the script tag. Mark html_safe afterwards so ERB does not turn quotes
    # into &quot; (crawlers need real JSON).
    tag.script(json_escape(json).html_safe, type: "application/ld+json")
  end

  def web_application_json_ld
    {
      "@context" => "https://schema.org",
      "@type" => "WebApplication",
      "name" => "Voterr",
      "alternateName" => "voterr.tv",
      "description" => DEFAULT_DESCRIPTION,
      "url" => "#{CANONICAL_ORIGIN}/",
      "applicationCategory" => "EntertainmentApplication",
      "operatingSystem" => "Web",
      "browserRequirements" => "Requires JavaScript for Plex OAuth sign-in. Guests can vote without JavaScript beyond standard form posts.",
      "offers" => {
        "@type" => "Offer",
        "price" => "0",
        "priceCurrency" => "USD"
      },
      "author" => person_json_ld,
      "publisher" => person_json_ld,
      "creator" => person_json_ld,
      "sameAs" => [GITHUB_REPO_URL, AUTHOR_URL, GITHUB_PROFILE_URL],
      "codeRepository" => GITHUB_REPO_URL,
      "image" => seo_image_url,
      "screenshot" => seo_image_url
    }
  end

  def person_json_ld
    {
      "@type" => "Person",
      "name" => AUTHOR_NAME,
      "url" => AUTHOR_URL,
      "sameAs" => [GITHUB_PROFILE_URL, AUTHOR_URL]
    }
  end
end
