# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header
#
# Notes on the allowances (kept deliberately close to the Rails 8 default):
# - script-src allows `https:` because the Plausible tracker URL is provided
#   via the PLAUSIBLE_SCRIPT_SRC env var (any https host) — see README
#   "Analytics". Inline scripts are still blocked, which is the main XSS win;
#   Rails' own importmap/Turbo bootstrap scripts are nonced automatically.
# - style-src allows 'unsafe-inline' for the small inline <style> blocks in
#   the landing layout and the Bulma-based inline styles.
# - img-src allows https: because movie posters are loaded from TMDB
#   (image.tmdb.org) and Plex-hosted images.
# - font-src covers Google Fonts (fonts.gstatic.com) and cdnjs (Font Awesome).
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src  :self, :https
    policy.font_src     :self, :https, :data
    policy.img_src      :self, :https, :data
    policy.object_src   :none
    policy.script_src   :self, :https
    policy.style_src    :self, :https, :unsafe_inline
    policy.frame_ancestors :self
    # Specify URI for violation reports
    # policy.report_uri "/csp-violation-report-endpoint"
  end

  # Generate session nonces for permitted importmap, inline scripts, and inline styles.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w(script-src)

  # Report violations without enforcing the policy.
  # config.content_security_policy_report_only = true
end