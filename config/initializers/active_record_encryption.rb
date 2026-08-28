# frozen_string_literal: true

# Active Record Encryption key configuration.
#
# Rails requires three explicit encryption credentials — without them ANY write
# to an encrypted attribute (User#plex_token) raises
# ActiveRecord::Encryption::Errors::Configuration ("Missing Active Record
# encryption credential") at runtime.
#
# This app carries no per-environment encryption credentials, so the keys are
# derived deterministically from the app's secret_key_base (stable per
# deployment). Trade-off: rotating secret_key_base invalidates stored
# ciphertext — users simply re-authenticate with Plex, which writes a fresh
# token. For dedicated keys, set ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY /
# _DETERMINISTIC_KEY / _KEY_DERIVATION_SALT env vars and they will take
# precedence instead (they are read by the Active Record railtie from
# credentials / app config — see db/encryption docs).
base = Rails.application.secret_key_base

if base.present?
  key_generator = ActiveSupport::KeyGenerator.new(base, hash_digest_class: OpenSSL::Digest::SHA256)
  derive = ->(label) { key_generator.generate_key("voterr active_record_encryption #{label}", 32) }

  Rails.application.config.active_record.encryption.primary_key = derive.call("primary_key")
  Rails.application.config.active_record.encryption.deterministic_key = derive.call("deterministic_key")
  Rails.application.config.active_record.encryption.key_derivation_salt = derive.call("key_derivation_salt")

  # Test fixtures ship plaintext tokens; tolerate reading them in the test
  # suite only. Production keeps strict behavior (unencrypted data unreadable).
  Rails.application.config.active_record.encryption.support_unencrypted_data = true if Rails.env.test?
else
  Rails.logger&.error(
    "Active Record Encryption unavailable: secret_key_base is missing. " \
    "Encrypted attributes (User#plex_token) will raise until SECRET_KEY_BASE is set."
  )
end