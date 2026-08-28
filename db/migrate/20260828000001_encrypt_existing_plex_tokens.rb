class EncryptExistingPlexTokens < ActiveRecord::Migration[8.0]
  def up
    # AR encryption ciphertext (JSON envelope) is longer than the ~28-char
    # plaintext token; widen the column before writing ciphertext.
    change_column :users, :plex_token, :text

    say_with_time "Encrypting existing plaintext plex_token values" do
      encrypted_count = 0
      already_count = 0

      rows = select_all(
        "SELECT id, plex_token FROM users WHERE plex_token IS NOT NULL AND plex_token <> ''"
      ).to_a

      rows.each do |row|
        raw = row["plex_token"]

        begin
          # Already encrypted under the configured keys — leave untouched.
          ActiveRecord::Encryption.encryptor.decrypt(raw)
          already_count += 1
        rescue StandardError
          # Not decryptable => legacy plaintext written before encryption was
          # enabled. Encrypt in place using the same keys the model uses.
          ciphertext = ActiveRecord::Encryption.encryptor.encrypt(raw)
          execute(
            "UPDATE users SET plex_token = #{connection.quote(ciphertext)} WHERE id = #{row['id']}"
          )
          encrypted_count += 1
        end
      end

      "encrypted #{encrypted_count} row(s), already encrypted #{already_count} row(s)"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot restore plaintext Plex tokens"
  end
end