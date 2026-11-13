-- 045: OAuth providers are linked to existing users.id; old players untouched.
CREATE TABLE IF NOT EXISTS user_auth_providers (
  provider text NOT NULL CHECK (provider IN ('google','apple')),
  provider_subject text NOT NULL CHECK (length(provider_subject) BETWEEN 1 AND 512),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(provider, provider_subject),
  UNIQUE(user_id, provider)
);
CREATE INDEX IF NOT EXISTS idx_user_auth_providers_user ON user_auth_providers(user_id);
COMMENT ON TABLE user_auth_providers IS
  'Verifying OAuth provider subject mapped to stable game user; never auto-merge by email.';
