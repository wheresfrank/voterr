# `secure: true` keeps the session cookie off plain-HTTP connections. Production
# also sets force_ssl (which marks cookies secure), but being explicit protects
# self-hosted deployments that run behind a proxy without force_ssl.
Rails.application.config.session_store :cookie_store, key: '_voterr_session', secure: Rails.env.production?