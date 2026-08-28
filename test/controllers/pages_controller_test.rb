require "test_helper"
require "json"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "homepage is a public 200 with plex movie-night voting copy" do
    get root_path

    assert_response :success
    assert_select "title", /Plex movie-night voting/
    assert_select "h1", /Plex movie-night/
    assert_select "meta[name='description']" do |elements|
      assert_match(/guests/i, elements.first["content"])
      assert_match(/Plex/i, elements.first["content"])
    end
    assert_select "link[rel='canonical'][href='https://www.voterr.tv/']"
    assert_select "meta[property='og:url'][content='https://www.voterr.tv/']"
    assert_select "meta[property='og:image'][content='https://www.voterr.tv/og-image.jpg']"
    assert_select "meta[name='robots'][content='index, follow']"
    assert_select "a[href='#{new_plex_auth_path}']", text: /Log in with Plex/
    assert_select "footer", /Frank Johnette/
    assert_select "footer a[href='https://frankjohnette.xyz']"
    assert_select "footer a[href='https://github.com/wheresfrank/voterr']"
  end

  test "homepage WebApplication JSON-LD uses the canonical site url" do
    get root_path

    assert_response :success
    payload = json_ld
    assert_equal "WebApplication", payload["@type"]
    assert_equal "https://www.voterr.tv/", payload["url"]
    assert_equal "https://github.com/wheresfrank/voterr", payload["codeRepository"]
    assert_equal "Frank Johnette", payload.dig("author", "name")
    assert_equal "Frank Johnette", payload.dig("publisher", "name")
    assert_includes payload["sameAs"], "https://github.com/wheresfrank/voterr"
  end

  test "about page names the author and links to GitHub" do
    get about_path

    assert_response :success
    assert_select "title", /About Voterr — Plex movie-night voting/
    assert_select "h1", /Plex movie-night voting/
    assert_select "a[href='https://github.com/wheresfrank/voterr']"
    assert_select "a[href='https://frankjohnette.xyz']"
    assert_select "link[rel='canonical'][href='https://www.voterr.tv/about']"
  end

  test "compare page covers hosted vs self-host and emits FAQPage JSON-LD" do
    get compare_path

    assert_response :success
    assert_select "h1", /no Docker/
    assert_select "h1", /guests/
    assert_match(/What to Watch on Plex/, response.body)
    assert_match(/MovieMatch/, response.body)
    assert_match(/Swiparr/, response.body)
    assert_match(/voterr.io/, response.body)
    payload = json_ld
    assert_equal "FAQPage", payload["@type"]
    assert payload["mainEntity"].any? { |item| item["name"].include?("voterr.io") }
  end

  test "privacy page is crawlable and mentions Plex OAuth" do
    get privacy_path

    assert_response :success
    assert_select "h1", "Privacy"
    assert_match(/Plex OAuth/, response.body)
    assert_match(/token/i, response.body)
    assert_select "link[rel='canonical'][href='https://www.voterr.tv/privacy']"
  end

  test "robots.txt allows the site, lists the sitemap, and is not cached for a year" do
    get "/robots.txt"

    assert_response :success
    assert_includes response.body, "Allow: /"
    assert_includes response.body, "Sitemap: https://www.voterr.tv/sitemap.xml"
    assert_includes response.body, "Disallow: /plex_auth/"
    refute_match(/# See https:\/\/www.robotstxt.org/, response.body)
    cache_control = response.headers["Cache-Control"].to_s
    assert_includes cache_control, "max-age=600"
    refute_match(/max-age=31536000/, cache_control)
  end

  test "sitemap.xml lists only public marketing urls" do
    get "/sitemap.xml"

    assert_response :success
    assert_includes response.body, "https://www.voterr.tv/"
    assert_includes response.body, "https://www.voterr.tv/about"
    assert_includes response.body, "https://www.voterr.tv/compare"
    assert_includes response.body, "https://www.voterr.tv/privacy"
    refute_includes response.body, "/plex_auth/"
    refute_includes response.body, "/sessions"
  end

  test "llms.txt describes voterr and disambiguates voterr.io" do
    get "/llms.txt"

    assert_response :success
    assert_match(/hosted Plex movie-night voting/i, response.body)
    assert_match(/not voterr\.io/i, response.body)
    assert_includes response.body, "https://github.com/wheresfrank/voterr"
    assert_includes response.body, "Frank Johnette"
    assert_match(/Rails/, response.body)
  end

  test "legacy keyword urls redirect to compare" do
    get "/faq"
    assert_redirected_to "/compare"

    get "/plex-movie-night"
    assert_redirected_to "/compare"
  end

  test "favicon and og image are real files" do
    get "/favicon.ico"
    assert_response :success
    assert_operator response.body.bytesize, :>, 100

    get "/og-image.jpg"
    assert_response :success
    assert_operator response.body.bytesize, :>, 1000
    assert_match %r{\Aimage/jpeg}, response.media_type.to_s
  end

  test "sessions dashboard still requires login" do
    get sessions_path

    assert_redirected_to new_plex_auth_path
  end

  private

  def json_ld
    document = Nokogiri::HTML(response.body)
    script = document.at_css('script[type="application/ld+json"]')
    assert script, "expected JSON-LD script tag"
    JSON.parse(script.text)
  end
end
