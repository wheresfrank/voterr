require "test_helper"

class PlexAuthControllerTest < ActionDispatch::IntegrationTest
  test "plex login page is noindex and is not the site canonical" do
    get new_plex_auth_path

    assert_response :success
    assert_select "meta[name='robots'][content='noindex, nofollow']"
    assert_select "link[rel='canonical'][href='https://www.voterr.tv/plex_auth/new']"
    assert_select "h1", /Log in/
    assert_select "script[type='application/ld+json']", count: 0
    assert_select "button[data-action='click->plex-auth#initiate']", text: /Log in with Plex/
  end

  test "login alias renders the same plex auth page" do
    get login_path

    assert_response :success
    assert_select "meta[name='robots'][content='noindex, nofollow']"
    assert_select "button[data-action='click->plex-auth#initiate']"
  end
end
