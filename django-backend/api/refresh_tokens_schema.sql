-- Refresh Tokens Table
-- Stores refresh tokens for JWT authentication with revocation capability
-- Part of ISSUE-37 fix: JWT refresh token implementation

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_id UUID NOT NULL UNIQUE,  -- Matches token_id in JWT payload
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked BOOLEAN DEFAULT FALSE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    device_info TEXT,  -- Optional: track which device/browser
    ip_address INET   -- Optional: track IP for security
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_token_id ON refresh_tokens(token_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);

-- Cleanup old/expired tokens periodically
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_revoked ON refresh_tokens(revoked) WHERE revoked = TRUE;

COMMENT ON TABLE refresh_tokens IS 'Stores JWT refresh tokens with revocation capability';
COMMENT ON COLUMN refresh_tokens.token_id IS 'UUID from JWT payload - used to revoke specific tokens';
COMMENT ON COLUMN refresh_tokens.revoked IS 'TRUE if token has been manually revoked (logout, security)';
